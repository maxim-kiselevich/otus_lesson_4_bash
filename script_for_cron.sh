#!/bin/bash

clear

logfile="/var/log/httpd/access_log"
varfile="/home/scripts/varfile.var"
lockfile="/home/scripts/lockfile.lock"

mail_body="/home/scripts/mail.txt"
mail_subject="Notification - Otus Lesson 4 - Bash"
mail_smtp=smtps://smtp.localhost:465
mail_from="mail.user@localhost"
mail_from_name="Otus Homework 4 Bash"
mail_user="mail.user@localhost"
mail_pass="passwd"
mail_nss="/etc/pki/nssdb/"
mail_recipient="mail.user@localhost"


if [ -f $lockfile ]
	then
		echo "Lockfile active, no new runs."
		cat "$lockfile"
		exit 1
	else
		echo "PID: $$" > $lockfile
		trap 'rm -f $lockfile"; exit $?' INT TERM EXIT
		echo "Working ..."
fi

if cat "$varfile" | grep -F "No such file or directory"
	then
		script_step_info="No such file or directory"
		line_start_number=1
		line_end_number=$(awk '{print $1}' "$logfile" | wc -l)
		line_export_var=$(awk '{ print $0 }' "$logfile" | sed -n "$line_end_number,$line_end_number"p | sed 's/[[]//; s/[]]//; s\/\ \g')
		line_processed=$line_end_number
		echo "$line_export_var" > "$varfile"
	else
		line_import_var=$(cat "$varfile")
		if	[ "$line_import_var" == "" ]
			then
				script_step_info="Empty varfile"
				line_start_number=1
				line_end_number=$(awk '{print $1}' "$logfile" | wc -l)
				line_export_var=$(awk '{ print $0 }' "$logfile" | sed -n "$line_end_number,$line_end_number"p | sed 's/[[]//; s/[]]//; s\/\ \g')
				line_processed=$line_end_number
				echo "$line_export_var" > "$varfile"	
			else
				if awk '{ print $0 }' "$logfile" | sed 's/[[]//; s/[]]//; s\/\ \g' | grep -F "$line_import_var"
					then
						script_step_info="Find processed line number"
						line_end_number=$(awk '{print $1}' "$logfile" | wc -l)
						line_export_var=$(awk '{ print $0 }' "$logfile" | sed -n "$line_end_number,$line_end_number"p | sed 's/[[]//; s/[]]//; s\/\ \g')
						line_processed_number=$(awk '{ print $0 }' "$logfile" | sed 's/[[]//; s/[]]//; s\/\ \g' | grep -F -n "$line_import_var" | cut -d: -f1)
						if	[ "$line_end_number" == "$line_processed_number" ]
							then
								script_step_info="End and processed number are equal"
								line_processed=0
								line_start_number=1
							else
								script_step_info="Find processed lines"
								let line_start_number="$line_processed_number + 1"
								let line_processed="$line_end_number - $line_start_number"
								echo "$line_export_var" > "$varfile"
						fi
					else
						script_step_info="No matching lines"
						line_start_number=1
						line_end_number=$(awk '{print $1}' "$logfile" | wc -l)
						line_export_var=$(awk '{ print $0 }' "$logfile" | sed -n "$line_end_number,$line_end_number"p | sed 's/[[]//; s/[]]//; s\/\ \g')
						line_processed=$line_end_number
						echo "$line_export_var" > "$varfile"
				fi		
		fi
fi



echo
echo "$script_step_info"
echo



date_time_start=$(date '+%d.%m.%Y in %H:%M:%S');
echo "Last run time $date_time_start" > $mail_body
echo >> $mail_body

start_processed_interval=$(awk '{ print $4, $5 }' "$logfile" | sed -n "$line_start_number,$line_start_number"p | sed 's/[[]//; s/[]]//; s\/\ \g' | awk -F ":" '{print $1, $2":"$3":"$4}')
end_processed_interval=$(awk '{ print $4, $5 }' "$logfile" | sed -n "$line_end_number,$line_end_number"p | sed 's/[[]//; s/[]]//; s\/\ \g' | awk -F ":" '{print $1, $2":"$3":"$4}')

echo "Processed interval: $start_processed_interval - $end_processed_interval" >> $mail_body

if	[ "$line_processed" == "0" ]
	then
		echo >> $mail_body
		echo "File has not changed since last run" >> $mail_body
		cat "$mail_body" | mailx -v -s "$mail_subject" -S ssl-verify=ignore -S smtp-auth=login -S smtp="$mail_smtp" -S from="$mail_from ($mail_from_name)" -S smtp-auth-user="$mail_user" -S smtp-auth-password="$mail_pass" -S ssl-verify=ignore -S nss-config-dir="$mail_nss" "$mail_recipient"
	else
		echo >> $mail_body
		echo "Total lines were processed is: $line_processed" >> $mail_body
		echo >> $mail_body
		echo "The first 20 IP who made a GET requests" >> $mail_body

		awk '{print $0}' $logfile | sed -n "$line_start_number,$line_end_number"p | awk '/GET/ { ip_count[$1]++ } END {
			for (i in ip_count) {
				print ip_count[i], "times was IP", i
				}
		}' | sort -rn | head -20 >> $mail_body

		echo >> $mail_body
		echo "The first 20 IP who made a HEAD requests" >> $mail_body

		awk '{print $0}' $logfile | sed -n "$line_start_number,$line_end_number"p | awk '/HEAD/ { ip_count[$1]++ } END {
			for (i in ip_count) {
				print ip_count[i], "times was IP", i
			}
		}' | sort -rn | head -20 >> $mail_body

		echo >> $mail_body
		echo "The first 20 URL requests" >> $mail_body

		awk '{print $0}' $logfile | sed -n "$line_start_number,$line_end_number"p | awk '/GET/ { url_count[$7]++ } END {
			for (i in url_count) {
				print url_count[i], "times was URL", i 
			}
		}' | sort -rn | head -20 >> $mail_body

		echo >> $mail_body
		echo "Error count" >> $mail_body

		awk '{print $9}' $logfile | sed -n "$line_start_number,$line_end_number"p | awk '/301|400|403|404|405|500/' | sort | uniq -c | sort -rn | awk '{ print $1, "times find error", $2 }' >> $mail_body

		echo >> $mail_body
		echo Error description: >> $mail_body
		echo 301 - Moved Permanently >> $mail_body
		echo 400 - Bad Request >> $mail_body
		echo 403 - Forbidden >> $mail_body
		echo 404 - Not Found >> $mail_body
		echo 405 - Method Not Allowed >> $mail_body
		echo 500 - Internal Server Error >> $mail_body

		cat "$mail_body" | mailx -v -s "$mail_subject" -S ssl-verify=ignore -S smtp-auth=login -S smtp="$mail_smtp" -S from="$mail_from ($mail_from_name)" -S smtp-auth-user="$mail_user" -S smtp-auth-password="$mail_pass" -S ssl-verify=ignore -S nss-config-dir="$mail_nss" "$mail_recipient"
fi


rm -f $lockfile
trap - INT TERM EXIT

exit 0


