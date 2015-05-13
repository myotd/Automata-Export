#!/bin/bash

escript=/tmp/otd$$
user=`id -un`
domain=`dnsdomainname`

if [ $# -lt 1 ]
  then
    echo only $# args
    echo "usage: $0 <file_with_automata_id in the first colume>"
    exit
fi

file=$1
esc_automata=""

echo "User: $user"
echo "Automaten:"
for automata in `cat $file | sed "s/\s.*//"`
do
  echo - $automata
  esc_automata+=" $automata*.xml"
done

echo  -n "password?" && read -s cred

cat <<OTD > $escript
log_user 0
set timeout 15
set send_human {.1 .3 1 .05 2}

spawn ssh $user@localhost -p 2222
expect {
   "yes/no" { send "yes\r" ; exp_continue }
   "password:" { send $cred\r }
   timeout { puts "\nError timeout login" ; exit}
   eof { puts "\nError no connection" ; exit }
}
expect { 
    "]>" { send -h "\r" }
    timeout { puts "timeout help\n" }
}
puts "\n Starting Export\r";
log_user 1
set timeout 30
OTD

for automata in `cat $file | sed "s/\s.*//"`
do
  exp_cmd="exportAutomatonByID(\\\"$automata\\\");" 
cat <<INL >> $escript
expect "]>"
send "$exp_cmd\r"
INL
done

cat <<EXP >>$escript
expect "]>" 
puts "\nclosing...\r"
close
wait

spawn ss 
expect {
   "# " { send "cd /home/ipcenter/.ipcenter_shell/$user/ && tar cvf /home/$user/exported_automata_$domain.tar $esc_automata\r" }
   "password" { send $cred\r ; exp_continue }
   timeout { puts "\nError timeout ss" ; exit}
   eof { puts "\nss failed" ; exit}
}
puts "\nExiting ss"
expect {
  "# " { send "exit\r"}
  timeout { puts "\nNo exit from ss" ; exit }
}
close 
wait
exit

EXP

expect -f $escript
rm $escript
exit