#!/bin/bash

### ===[ Настраиваемые параметры ]===
WARN_USAGE=80
CRIT_USAGE=95

# === Цвета (только при наличии TERM) ===
if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    RESET=$(tput sgr0)
    BOLD=$(tput bold)
else
    RED='' GREEN='' YELLOW='' CYAN='' RESET='' BOLD=''
fi


### ===[ Заголовок ]===
echo "
 _______________
< Vectoooooor >
 ---------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/
                ||----w |
                ||     ||
"
echo -e "${RED}$(grep PRETTY_NAME /etc/*release 2>/dev/null | head -n1 | cut -d= -f2 | tr -d '"')${RESET}"

### ===[ Кэши systemd ]===
ALL_UNITS=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | sed 's/\.service$//')
ENABLED_UNITS=$(systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | sed 's/\.service$//')

function has_unit()    { echo "$ALL_UNITS"    | grep -qx "$1"; }
function is_enabled()  { echo "$ENABLED_UNITS" | grep -qx "$1"; }

# === Mapping compose project → systemd unit через WorkingDirectory ===
# Строим: для каждого compose unit получаем WorkingDirectory,
# потом ищем unit по совпадению /opt/containers/<project>
declare -A UNIT_BY_PROJECT
while read -r unit_name; do
    [[ -z "$unit_name" ]] && continue
    wd=$(systemctl show "$unit_name.service" --property=WorkingDirectory --value 2>/dev/null)
    [[ -z "$wd" || ! -d "$wd" ]] && continue
    # Проект = последний компонент пути (/opt/containers/backup → backup)
    project=$(basename "$wd")
    UNIT_BY_PROJECT["$project"]="$unit_name"
done < <(systemctl list-units --all --type=service --no-legend 2>/dev/null | awk '/compose/ {print $1}' | sed 's/\.service$//')

function get_unit_for_project() {
    local project="$1"
    if [[ -n "${UNIT_BY_PROJECT[$project]}" ]]; then
        echo "${UNIT_BY_PROJECT[$project]}"
    else
        echo "${project}-compose"
    fi
}

### ===[ Host Services ]===
echo -e "\n${CYAN}=== Host Services ===${RESET}"
printf "${BOLD}%-12s %-15s %-6s %-6s %s${RESET}\n" "STATUS" "SERVICE" "UNIT" "AUTO" "DESCRIPTION"

HOST_SERVICES="nginx php-fpm fail2ban sshd firewalld chronyd crond"

for svc in $HOST_SERVICES; do
    active=$(systemctl is-active "$svc.service" 2>/dev/null)
    desc=$(systemctl show "$svc.service" --property=Description --value 2>/dev/null | head -c 55)

    unit_mark="✗"; auto_mark="✗"
    has_unit "$svc" && unit_mark="✓"
    is_enabled "$svc" && auto_mark="✓"

    if [[ "$active" == "active" ]]; then
        printf "%-12s %-15s %-6s %-6s %s\n" "${GREEN}running${RESET}" "$svc" "$unit_mark" "$auto_mark" "$desc"
    else
        printf "%-12s %-15s %-6s %-6s %s\n" "${RED}stopped${RESET}" "$svc" "$unit_mark" "$auto_mark" "$desc"
    fi
done

# === Special: vsftpd migration ===
vsftpd_host=$(systemctl is-active vsftpd.service 2>/dev/null)
vsftpd_container=$(podman inspect vsftpd --format '{{.State.Status}}' 2>/dev/null)

if [[ "$vsftpd_host" != "active" && "$vsftpd_container" == "running" ]]; then
    printf "%-12s %-15s %-6s %-6s %s\n" \
        "${YELLOW}migrating${RESET}" "vsftpd" "✓" "✓" "host:inactive → container:running"
fi

### ===[ Container Groups ]===
echo -e "\n${CYAN}=== Container Groups ===${RESET}"
printf "${BOLD}%-12s %-15s %-6s %-6s %s${RESET}\n" "STATUS" "GROUP" "UNIT" "AUTO" "CONTAINERS"

# Собираем данные о контейнерах через podman inspect
declare -A C_STATE C_HEALTHY C_MAINTENANCE
declare -A PROJECT_CONTAINERS

container_ids=$(podman ps -aq 2>/dev/null)
if [[ -n "$container_ids" ]]; then
    while IFS='|' read -r name state health project maintenance; do
        [[ -z "$project" || "$project" == "<no value>" ]] && continue

        # Пропускаем vsftpd из групп — показываем в Host Services как migrating
        [[ "$project" == "vsftpd" && "$vsftpd_host" != "active" && "$vsftpd_container" == "running" ]] && continue

        C_STATE["$name"]="$state"
        C_HEALTHY["$name"]="$health"
        C_MAINTENANCE["$name"]="$maintenance"
        PROJECT_CONTAINERS["$project"]="${PROJECT_CONTAINERS["$project"]} $name"
    done < <(podman inspect --format '{{.Name}}|{{.State.Status}}|{{if .State.Healthcheck}}{{.State.Healthcheck.Status}}{{else}}none{{end}}|{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.maintenance"}}' $container_ids 2>/dev/null)
fi

# Сортируем проекты
if [[ ${#PROJECT_CONTAINERS[@]} -gt 0 ]]; then
    projects_sorted=$(printf '%s\n' "${!PROJECT_CONTAINERS[@]}" | sort)

    while IFS= read -r project; do
        containers=${PROJECT_CONTAINERS["$project"]}
        total=0; running=0; details=""; all_maint=true

        for cname in $containers; do
            total=$((total + 1))
            state=${C_STATE["$cname"]}
            health=${C_HEALTHY["$cname"]}
            maintenance=${C_MAINTENANCE["$cname"]}

            if [[ "$state" == "running" ]]; then
                running=$((running + 1))
                if [[ "$health" == "healthy" ]]; then
                    details="$details, $cname ✓ healthy"
                else
                    details="$details, $cname ✓"
                fi
            else
                if [[ "$maintenance" == "true" ]]; then
                    details="$details, $cname 🛠 maintenance"
                else
                    details="$details, $cname ✗"
                    all_maint=false
                fi
            fi
        done

        details=${details#, }

        # Статус группы
        if [[ "$running" -eq "$total" ]]; then
            group_status="${GREEN}running${RESET}"
        elif [[ "$running" -eq 0 ]]; then
            if $all_maint; then
                group_status="${YELLOW}maintenance${RESET}"
            else
                group_status="${RED}STOPPED${RESET}"
            fi
        else
            group_status="${YELLOW}partial${RESET}"
        fi

        # UNIT / AUTO — через mapping compose project → systemd unit
        compose_unit=$(get_unit_for_project "$project")
        unit_mark="✗"; auto_mark="✗"
        has_unit "$compose_unit" && unit_mark="✓"
        is_enabled "$compose_unit" && auto_mark="✓"

        printf "%-12s %-15s %-6s %-6s (%d/%d) %s\n" \
            "$group_status" "$project" "$unit_mark" "$auto_mark" "$running" "$total" "$details"
    done <<< "$projects_sorted"
fi

### ===[ Security / Updates ]===
echo -e "\n${CYAN}=== Security / Updates ===${RESET}"

# Дата последнего dnf обновления (локально, без сети)
if [[ -f /var/lib/dnf/history.sqlite ]]; then
    last_dnf=$(stat -c "%y" /var/lib/dnf/history.sqlite 2>/dev/null | cut -d' ' -f1)
    echo "Last package update: $last_dnf"
fi

# Pending конфиги от rpm
rpmnew_count=$(find /etc -maxdepth 3 -name "*.rpmnew" -o -name "*.rpmsave" 2>/dev/null | wc -l)
if [[ "$rpmnew_count" -gt 0 ]]; then
    echo -e "${YELLOW}Pending config merges: $rpmnew_count${RESET}"
fi

# Podman ресурсы (быстро, ~1.5с)
if command -v podman &>/dev/null; then
    podman system df 2>/dev/null | grep -E '^(Images|Containers|Local Volumes)' | while read -r line; do
        echo "$line"
    done
fi

### ===[ Кто залогинен ]===
echo -e "\n${CYAN}--- Who is logged in ---${RESET}"
w | head -n 5

### ===[ Последние подключения ]===
echo -e "\n${CYAN}--- Last Logins ---${RESET}"
last -aF | head -n4 | tail -n3

### ===[ Диски ]===
echo -e "\n${CYAN}--- Disk Usage (above ${WARN_USAGE}%) ---${RESET}"
df -h -x tmpfs -x devtmpfs -x squashfs | while read -r line; do
    if echo "$line" | grep -qE '^Filesystem'; then
        echo "$line"
        continue
    fi
    usep=$(echo "$line" | awk '{ print $(NF-1) }' | tr -d '%')
    [[ ! "$usep" =~ ^[0-9]+$ ]] && continue
    if [ "$usep" -ge "$CRIT_USAGE" ]; then
        echo -e "${RED}${line}${RESET}"
    elif [ "$usep" -ge "$WARN_USAGE" ]; then
        echo -e "${YELLOW}${line}${RESET}"
    fi
done


echo -e "\n${CYAN}--- Uptime ---${RESET}"
uptime
