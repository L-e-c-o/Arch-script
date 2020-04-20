#!/bin/bash

# checking for args
if [ "$#" -ne 2 ]; then
    echo "Please enter 2 arguments (1:log file  (2:output file (with no extension)"
    echo "Syntax example:" 
    echo "./sort_log.sh  my_log_file   my_output_file "
    exit
fi

# decode url function
urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}";}

# check if file exists
if [ -f "$2.csv" ]; then
    f=c
    read -p "File $2 already exists. Do you want to replace it ? [Y/n] " resp
    while [[ $resp != "y" && $resp != "n" && $resp != "" ]]
    do
        read -p "Please enter a valid choice : [Y/n] " resp
    done
elif [ -f "$2.html" ]; then
    f=h
    read -p "File $2 already exists. Do you want to replace it ? [Y/n] " resp
    while [[ $resp != "y" && $resp != "n" && $resp != "" ]]
    do
        read -p "Please enter a valid choice : [Y/n] " resp
    done
fi    
    if [[ $resp == "n" ]]; then
       exit
    fi
if [ $f == "c" ]; then
    rm "$2.csv"
else
    rm "$2.html"
fi

# choose export format
echo "1-CSV"                            
echo "2-HTML"                           
read -p "Choose your export format :" ch
while [[ $ch != "1" && $ch != "2" ]]
do
    read -p "Please enter a valid choice : [1/2] " ch
done

# csv export 
cat $1 | grep fullName | awk -F " " {'print $1 " " $4 " " $7'} | sed -e 's/\/bigblue.*fullName=//' -e 's/\[//' -e 's/\&join.*$//' -e 's/\+/ /'>tmp.txt 
while read p; do
  urldecode $p >> $2 
done <tmp.txt 
rm tmp.txt
cat $2 | sed -e 's/\s\+/,/' -e 's/\s\+/,/' -e 's/:/,/1' | awk -F "," '{print $4","$3","$1","$2}' | sed 's/Ancien de/Ancien-de/g'| sort -t, -k4 -k2 -k1 >> tmp.txt
if [[ $ch == "1" ]]; then
    cp tmp.txt "$2.csv" 
else

# html export
echo '<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>BBB log parser</title><link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css"></head><body><table class="table table-striped table-dark"><thead><tr><th scope="col">Nom</th><th scope="col">Heure</th><th scope="col">IP</th><th scope="col">Date</th></tr></thead><tbody>' >"$2.html"
cat tmp.txt | awk -F "," '{print "<tr><td>"$1"</td><td>"$2"</td><td>"$3"</td><td>"$4"</td><td>"$5"</td></tr>"}' >> "$2.html"    
echo '</tbody></table></body></html>'>>"$2".html
fi

# remove temp files
rm $2 tmp.txt
echo "Export finished with success."
