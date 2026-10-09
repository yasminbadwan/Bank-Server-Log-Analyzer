#!/bin/bash

# Log file used by all reports
LOG_FILE="bank_server.log"

validate_file() {
    # Checks that the required log file exists before the program starts
    if [ ! -f "$LOG_FILE" ]
    then
        echo "Error: Log file not found."
        exit 1
    fi
}

show_menu() {
    # Displays all available services and reads the user choice
    echo "------------------------------"
    echo " Bank Server Log Analyzer"
    echo "------------------------------"
    echo "1. Failed Login Report"
    echo "2. Query Activity Summary"
    echo "3. Slow Query Detector"
    echo "4. Transaction Report"
    echo "5. Critical Events Report"
    echo "6. User Activity Report"
    echo "7. Login/Logout Session Report"
    echo "8. Events-per-Hour Report"
    echo "9. General Log Summary"
    echo "10. Run All Reports"
    echo "0. Exit"

    read -p "Enter your choice: " choice
}

failed_login_report()
{
    # Summarizes failed logins and flags possible brute-force IP addresses
    echo "========================================"
    echo "          FAILED LOGIN REPORT"
    echo "========================================"
    echo ""

    # Total number of failed login attempts
    failed_count=$(grep "Failed login attempt" "$LOG_FILE" | grep "\[AUTH\]" | grep "\[ERROR\]" | wc -l)

    echo "Total Failed Login Attempts: $failed_count"
    echo ""

    # Group failed login attempts by CLIENT_IP
    echo "----------------------------------------"
    echo "Failed Attempts by IP"
    echo "----------------------------------------"

    grep "Failed login attempt" "$LOG_FILE" | grep "\[AUTH\]" | grep "\[ERROR\]" |
    cut -d'[' -f6 | cut -d']' -f1 |
    sort | uniq -c

    echo ""

    # Group failed login attempts by USER
    echo "----------------------------------------"
    echo "Failed Attempts by User"
    echo "----------------------------------------"

    grep "Failed login attempt" "$LOG_FILE" | grep "\[AUTH\]" | grep "\[ERROR\]" |
    cut -d'[' -f5 | cut -d']' -f1 |
    sort | uniq -c

    echo ""

    # Detect possible brute-force IP addresses
    echo "----------------------------------------"
    echo "Possible Brute-Force Sources"
    echo "----------------------------------------"

    grep "Failed login attempt" "$LOG_FILE" | grep "\[AUTH\]" | grep "\[ERROR\]" |
    cut -d'[' -f6 | cut -d']' -f1 |
    sort | uniq -c |
    while read count ip
    do
        if [ "$count" -ge 3 ]
        then
            echo "$ip - $count failed attempts"
        fi
    done

    echo ""
    echo "========================================"
    echo "              END REPORT"
    echo "========================================"
}

query_activity_summary()
{
    # Counts QUERY events and breaks them down by SQL query type
    echo "========================================"
    echo "          QUERY ACTIVITY SUMMARY"
    echo "========================================"
    echo ""

    # Total number of QUERY events
    query_count=$(grep "\[QUERY\]" "$LOG_FILE" | wc -l)

    echo "Total Query Events: $query_count"
    echo ""

    echo "----------------------------------------"
    echo "Query Types"
    echo "----------------------------------------"

    # Count SELECT queries
    select_count=$(grep "\[QUERY\]" "$LOG_FILE" | grep "SELECT" | wc -l)
    echo "SELECT Queries: $select_count"

    # Count UPDATE queries
    update_count=$(grep "\[QUERY\]" "$LOG_FILE" | grep "UPDATE" | wc -l)
    echo "UPDATE Queries: $update_count"

    # Count INSERT queries
    insert_count=$(grep "\[QUERY\]" "$LOG_FILE" | grep "INSERT" | wc -l)
    echo "INSERT Queries: $insert_count"

    # Count DELETE queries
    delete_count=$(grep "\[QUERY\]" "$LOG_FILE" | grep "DELETE" | wc -l)
    echo "DELETE Queries: $delete_count"

    echo ""
    echo "========================================"
    echo "              END REPORT"
    echo "========================================"
}

slow_query_detector()
{
    # Lists slow WARNING queries with the responsible user and execution time
    echo "========================================"
    echo "          SLOW QUERY DETECTOR"
    echo "========================================"
    echo ""

    echo "----------------------------------------"
    echo "Slow Query Details"
    echo "----------------------------------------"

    grep "\[WARNING\]" "$LOG_FILE" | grep "\[QUERY\]" | grep -i "slow"|
    while read line
    do
        user=$(echo "$line" | cut -d'[' -f5 | cut -d']' -f1)

        execution_time=$(echo "$line" | grep -oE "[0-9.]+[[:space:]]*(ms|seconds)")

        echo "User: $user"
        echo "Execution Time: $execution_time"
        echo "----------------------------------------"
    done

    echo ""
    echo "========================================"
    echo "              END REPORT"
    echo "========================================"
}

transaction_report()
{
    # Summarizes transaction counts and total deposited/withdrawn amounts
    echo "========================================"
    echo "          TRANSACTION REPORT"
    echo "========================================"
    echo ""

    # Count deposits
    deposit_count=$(grep "\[TRANSACTION\]" "$LOG_FILE" | grep -i "Deposit amount" | wc -l)

    # Count withdrawals
    withdrawal_count=$(grep "\[TRANSACTION\]" "$LOG_FILE" | grep -i "Withdrawal amount" | wc -l)

    # Count declined transactions
    declined_count=$(grep "\[TRANSACTION\]" "$LOG_FILE" | grep -i "Transaction declined" | wc -l)

    # Count rollbacks
    rollback_count=$(grep "\[TRANSACTION\]" "$LOG_FILE" | grep -i "Transaction rollback" | wc -l)

    echo "----------------------------------------"
    echo "Transaction Counts"
    echo "----------------------------------------"

    echo "Total Deposits: $deposit_count"
    echo "Total Withdrawals: $withdrawal_count"
    echo "Declined Transactions: $declined_count"
    echo "Rollbacks: $rollback_count"
    echo ""

    # Calculate total deposited amount
    total_deposit=0

    while read line
    do
        amount=$(echo "$line" | grep -oiE "Deposit amount[[:space:]]+[0-9]+([.][0-9]+)?" | grep -oE "[0-9]+([.][0-9]+)?$")

        if [ -n "$amount" ]
        then
            total_deposit=$(awk -v total="$total_deposit" -v value="$amount" 'BEGIN {print total + value}')
        fi

    done < <(grep "\[TRANSACTION\]" "$LOG_FILE" | grep -i "Deposit amount")

    # Calculate total withdrawn amount
    total_withdrawal=0

    while read line
    do
        amount=$(echo "$line" | grep -oiE "Withdrawal amount[[:space:]]+[0-9]+([.][0-9]+)?" | grep -oE "[0-9]+([.][0-9]+)?$")

        if [ -n "$amount" ]
        then
            total_withdrawal=$(awk -v total="$total_withdrawal" -v value="$amount" 'BEGIN {print total + value}')
        fi

    done < <(grep "\[TRANSACTION\]" "$LOG_FILE" | grep -i "Withdrawal amount")

    echo "----------------------------------------"
    echo "Transaction Amounts"
    echo "----------------------------------------"

    echo "Total Deposited Amount: $total_deposit"
    echo "Total Withdrawn Amount: $total_withdrawal"

    echo ""
    echo "========================================"
    echo "              END REPORT"
    echo "========================================"
}

critical_events_report()
{
    # Lists all CRITICAL events with their timestamps and messages
    echo "========================================"
    echo "         CRITICAL EVENTS REPORT"
    echo "========================================"
    echo ""

    echo "----------------------------------------"
    echo "Critical Events"
    echo "----------------------------------------"

    grep "\[CRITICAL\]" "$LOG_FILE" |
    while IFS= read -r line
    do
        timestamp=$(echo "$line" | cut -d'[' -f2 | cut -d']' -f1)

        message=$(echo "$line" | cut -d']' -f7 | cut -d'-' -f2-)

        echo "Time: $timestamp"
        echo "Event:$message"
        echo "----------------------------------------"
    done

    echo ""
    echo "========================================"
    echo "              END REPORT"
    echo "========================================"
}

user_activity_report() {
    # Displays all actions for a given username in chronological order
    local username="$1"

    # Ask for a username only when the function is called directly
    if [ -z "$username" ]
    then
        read -r -p "Enter username: " username
    fi

    if [ -z "$username" ]
    then
        echo "Error: Username cannot be empty."
        return 1
    fi

    # Check if the username exists (case-insensitive)
    user_found=$(awk -v user="$username" '
    BEGIN {
        user=tolower(user)
    }
    {
        current_user=$5
        gsub(/\[/, "", current_user)
        gsub(/\]/, "", current_user)

        if (tolower(current_user) == user)
            count++
    }
    END {
        print count+0
    }
    ' "$LOG_FILE")

    if [ "$user_found" -eq 0 ]
    then
        echo "No activity found for user: $username"
        return 1
    fi

    echo ""
    echo "========================================"
    echo "      USER ACTIVITY REPORT"
    echo "========================================"
    echo "User: $username"
    echo ""

    # Print matching actions, then sort them by date and time
    awk -v user="$username" '
    BEGIN {
        user=tolower(user)
    }
    {
        current_user=$5
        gsub(/\[/, "", current_user)
        gsub(/\]/, "", current_user)

        if (tolower(current_user) == user)
            print
    }
    ' "$LOG_FILE" | sort -k1,2

    echo "========================================"
}

session_report() {
    # Displays login and logout times and duration for each session


    echo ""
    echo "========================================"
    echo "        LOGIN/LOGOUT SESSION REPORT"
    echo "========================================"

    sort "$LOG_FILE" | awk '

    # Checks whether a year is a leap year
    function leap_year(year) {
        if ((year % 400 == 0) || ((year % 4 == 0) && (year % 100 != 0)))
            return 1
        else
            return 0
    }

    # Converts a date into number of days
    function date_to_days(date, parts, year, month, day, days, y, m) {

        split(date, parts, "-")

        year=parts[1]
        month=parts[2]
        day=parts[3]

        days=0

        for (y=1970; y<year; y++) {
            if (leap_year(y))
                days += 366
            else
                days += 365
        }

        month_days[1]=31
        month_days[2]=28
        month_days[3]=31
        month_days[4]=30
        month_days[5]=31
        month_days[6]=30
        month_days[7]=31
        month_days[8]=31
        month_days[9]=30
        month_days[10]=31
        month_days[11]=30
        month_days[12]=31

        if (leap_year(year))
            month_days[2]=29

        for (m=1; m<month; m++)
            days += month_days[m]

        days += day

        return days
    }

    # Converts date and time to seconds
    function to_seconds(date, time, t, days) {

        split(time, t, ":")

        days=date_to_days(date)

        return days*86400 + t[1]*3600 + t[2]*60 + t[3]
    }

    {
        date=$1
        gsub(/\[/, "", date)

        time=$2
        gsub(/\]/, "", time)

        session=$4
        gsub(/\[/, "", session)
        gsub(/\]/, "", session)

        # Save each session once
        if (!(session in seen)) {
            seen[session]=1
            order[++session_count]=session
        }

        # Store first successful login
        if ($0 ~ /Successful login/ && !(session in login_seconds)) {

            login_time[session]=date " " time
            login_seconds[session]=to_seconds(date, time)
        }

        # Store logout
        if ($0 ~ /Logout/) {

            logout_time[session]=date " " time
            logout_seconds[session]=to_seconds(date, time)
        }
    }

    END {

        printf "%-18s %-20s %-20s %-18s\n", \
        "SESSION", "LOGIN", "LOGOUT", "DURATION"

        printf "-------------------------------------------------------------------------------\n"

        for (i=1; i<=session_count; i++) {

            s=order[i]

            if (s in login_time)
                login_display=login_time[s]
            else
                login_display="N/A"

            if (s in logout_time)
                logout_display=logout_time[s]
            else
                logout_display="N/A"

            if ((s in login_seconds) && (s in logout_seconds)) {

                duration=logout_seconds[s]-login_seconds[s]

                if (duration >= 0) {

                    days=int(duration/86400)
                    hours=int((duration%86400)/3600)
                    minutes=int((duration%3600)/60)
                    seconds=duration%60

                    duration_display=""

                    if (days > 0)
                        duration_display=duration_display days "d "

                    if (hours > 0)
                        duration_display=duration_display hours "h "

                    if (minutes > 0)
                        duration_display=duration_display minutes "m "

                    if (seconds > 0)
                        duration_display=duration_display seconds "s"

                    if (duration_display == "")
                        duration_display="0s"
                }
                else {
                    duration_display="Invalid"
                }
            }
            else {
                duration_display="N/A"
            }

            printf "%-18s %-20s %-20s %-18s\n", \
            s, login_display, logout_display, duration_display
        }
    }
    '

    echo "========================================"
}

events_per_hour_report() {
    # Counts the number of log events that occurred during each hour



    echo ""
    echo "========================================"
    echo "        EVENTS PER HOUR REPORT"
    echo "========================================"

    awk '
    {
        time=$2
        gsub(/\]/, "", time)

        split(time, parts, ":")
        hour=parts[1]

        count[hour]++
    }

    END {
        printf "%-10s %-10s\n", "HOUR", "EVENTS"
        printf "--------------------\n"

        for (i=0; i<=23; i++) {

            hour=sprintf("%02d", i)

            printf "%-10s %-10d\n", \
            hour ":00", count[hour]+0
        }
    }
    ' "$LOG_FILE"

    echo "========================================"
}

general_log_summary() {
    # Displays a general summary of the log file


    total_lines=$(wc -l < "$LOG_FILE")

    echo ""
    echo "========================================"
    echo "          GENERAL LOG SUMMARY"
    echo "========================================"

    echo "Total log events : $total_lines"
    echo ""

    awk '
    {
        level=$3
        gsub(/\[/, "", level)
        gsub(/\]/, "", level)

        module=$7
        gsub(/\[/, "", module)
        gsub(/\]/, "", module)

        level_count[level]++
        module_count[module]++
    }

    END {

        print "Events by log level:"
        printf "INFO             : %d\n", level_count["INFO"]+0
        printf "WARNING          : %d\n", level_count["WARNING"]+0
        printf "ERROR            : %d\n", level_count["ERROR"]+0
        printf "CRITICAL         : %d\n", level_count["CRITICAL"]+0

        print ""

        max=0

        for (module in module_count) {
            if (module_count[module] > max)
                max=module_count[module]
        }

        printf "Busiest module(s): "

        first=1

        for (module in module_count) {

            if (module_count[module] == max) {

                if (first == 0)
                    printf ", "

                printf "%s", module

                first=0
            }
        }

        printf " (%d events)\n", max
    }
    ' "$LOG_FILE"

    echo "========================================"
}

run_all_reports()
{
    # Runs all services and saves the combined output in a full report file
    REPORT_FILE="full_report.txt"

    # User Activity needs a username, so ask for it once before generating the full report
    while true
    do
        read -r -p "Enter username for User Activity Report: " report_username

        if [ -z "$report_username" ]
        then
            echo "Error: Username cannot be empty."
            continue
        fi

        user_found=$(awk -v user="$report_username" '
        BEGIN { user=tolower(user) }
        {
            current_user=$5
            gsub(/\[/, "", current_user)
            gsub(/\]/, "", current_user)
            if (tolower(current_user) == user)
                count++
        }
        END { print count+0 }
        ' "$LOG_FILE")

        if [ "$user_found" -eq 0 ]
        then
            echo "No activity found for user: $report_username"
        else
            break
        fi
    done

    {
        echo "========================================"
        echo "          FULL BANK LOG REPORT"
        echo "========================================"
        echo ""

        failed_login_report
        echo ""

        query_activity_summary
        echo ""

        slow_query_detector
        echo ""

        transaction_report
        echo ""

        critical_events_report
        echo ""

        user_activity_report "$report_username"
        echo ""

        session_report
        echo ""

        events_per_hour_report
        echo ""

        general_log_summary

        echo ""
        echo "========================================"
        echo "            END FULL REPORT"
        echo "========================================"

    } | tee "$REPORT_FILE"

    echo ""
    echo "Full report saved to: $REPORT_FILE"
}
#------------------------------------------------------------------------------
#main
#------------------------------------------------------------------------------
validate_file

echo "=========================================================="
echo "          BANK DATABASE SERVER LOG ANALYZER"
echo "=========================================================="
echo

echo "Welcome to the Bank Database Server Log Analyzer!"
echo

echo "This project was developed by:"
echo "  - Yasmin"
echo "  - Sanabel"

while true
do
    show_menu

    case $choice in
        1)
            failed_login_report
            ;;
        2)
            query_activity_summary
            ;;
        3)
            slow_query_detector
            ;;
        4)
            transaction_report
            ;;
        5)
            critical_events_report
            ;;
        6)
            user_activity_report
            ;;
        7)
            session_report
            ;;
        8)
            events_per_hour_report
            ;;
        9)
            general_log_summary
            ;;
        10)
            run_all_reports
            ;;
        0)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done
