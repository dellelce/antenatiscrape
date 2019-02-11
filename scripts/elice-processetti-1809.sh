#!/bin/bash
#
# File:         morti.sh
# Created:      291218
# Description:
#

## FUNCTIONS ##

now ()
{
 export now=$(date +%H%M_%d%m%y);
 echo $now
}

log()
{
  [  -z "$*" ] && { echo >> "$log"; return 0; }
  echo "$(now) $*" >> "$log"
}

base_url()
{
 typeset base="${base_site}/v/Archivio+di+Stato+di+${province}/${group}"
 typeset url="$base/$place/${type}/$1/"

 echo "$url"

 log base_url  $url
}

base_year()
{
 typeset year="$1"
 typeset url=$(base_url $year)
 typeset output="${prefix}_${year}.years.html"

 wget -T "${timeout}" -q -O "${output}" "$url"
 typeset rc=$?

 [ "$rc" -ne 0 ] &&
 {
   log "base_year wget fail rc=$rc"
   [ -f "$output" -a ! -s "$output" ] && rm "$output" # do not keep empty files
 }
 return $rc
}

full_urls()
{
 typeset year="$1"
 typeset basefile="${prefix}_${year}.years.html"
 typeset rc=0

 [ ! -f "$basefile" ] && { base_year "$year"; rc=$?; }
 [ "$rc" -ne 0 ] && { log "full_urls base_year failed: rc=$?"; return $rc; }
 [ ! -s "$basefile" ] && { rm "$basefile"; return 1; }

 log full_urls "year=$year basefile=$basefile"

 awk -F\" -vbase=$base_site -vtype=$type \
'
 $0 ~ type &&/href/&&!/class/ { print base""$2 }
' "$basefile"
}

image_ids()
{
 typeset year="$1"
 typeset urls="$(base_url $1)"

 for url in $urls
 do
   base=$(echo "$url" | awk ' { gsub(/?g2_page=/,"");
                                c=split($0, a, "/"); base=a[c-1]; print base "_"a[c]; } 
        ')
   new_path="${prefix}_${year}_${base}.fullyear.html"

   log "image_ids base=$base new_path=${new_path}"

   [ ! -f "$new_path" ] && wget -T "${timeout}" -q -O "${new_path}" "$url"
   [ ! -s "$new_path" ] && { rm "$new_path"; return 1; }

   log "image_ids url=$url"

   awk \
       -vyear=$year \
       -vmax_photos=$year \
       -vbase=$base \
'
   /g2_itemId/ \
   {
     line=$0
     gsub(/[;=&]/, " ", line);
     cnt = split(line, line_a, " ");
     imgid = line_a[7]
   }

   /[0-9]\.jpg\.html/ \
   {
     line=$0
     split(line, line_a, "\"");
     s = line_a[2]

     url_cnt = split(s, url_a, "/");
     name = url_a[url_cnt]
     id=name
     gsub(/\.jpg\.html/,"",id);

   }
   /^Immagine / \
   {
     gsub(/[<>]/, " ", $0);
     img=$2
     print year " " img " " imgid " " base
   }
' "$new_path"
 done
}

image_ids_url()
{
 typeset year="$1"; shift
 typeset url="$1"

 [ -z "$url" ] && return 1
 base=$(echo "$url" | awk ' { gsub(/?g2_page=/,"");
                                c=split($0, a, "/"); base=a[c-1]; print base "_"a[c]; }
       ')
 new_path="${prefix}_${year}_${base}.fullyear.html"

 log "image_ids_url base=$base new_path=${new_path}"

 [ ! -f "$new_path" ] && wget -T "${timeout}" -q -O "${new_path}" "$url"
 [ ! -s "$new_path" ] && { rm "$new_path"; return 1; }

 log "image_ids_url url=$url"

 awk \
       -vyear=$year \
       -vmax_photos=$year \
       -vbase=$base \
'
   /g2_itemId/ \
   {
     line=$0
     gsub(/[;=&]/, " ", line);
     cnt = split(line, line_a, " ");
     imgid = line_a[7]
   }

   /[0-9]\.jpg\.html/ \
   {
     line=$0
     split(line, line_a, "\"");
     s = line_a[2]

     url_cnt = split(s, url_a, "/");
     name = url_a[url_cnt]
     id=name
     gsub(/\.jpg\.html/,"",id);

   }
   /^Immagine / \
   {
     gsub(/[<>]/, " ", $0);
     img=$2
     print year " " img " " imgid " " base
   }
' "$new_path"
}

# given an image id return the full to the (large) image
image_url()
{
 typeset id="$1"

 echo "${base_site}/gallery2/main.php?g2_view=core.DownloadItem&g2_itemId=${id}&g2_serialNumber=2"
}

main()
{
 typeset years="$*"
 typeset year
 typeset skipcnt=0

 log ""
 log "===== start ====="

 for year in $years
 do
   # MISSING: get_urls from year!
   typeset maxpos=0
   for url in $urls
   do
     image_ids_url "$year" "$url" | while read y pos id base
     do
       let maxpos="(( $maxpos + 1 ))"
       [ "$pos" -gt "$max_photos" ] && continue

       #only for debugging naming issues->
       #log "main pos=$pos maxpos=$maxpos"

       # 1st first image = large
       # 2nd image = icon
       # 3rd image = medium
       # wtf!?
       let good_id="$(( $id - 1 ))"

       typeset full_url=$(image_url "$good_id")
       typeset image_file="${prefix}_${year}_${pos}.jpg"

       [ ! -z "$base" -a "${base}" != "${base/suppl/}" ] &&
       {
         # if base has keyword "suppl" create a custom image file"
       
         typeset image_file_ext=$(echo $base | awk -F+ ' { print $2$3; } ')
         #typeset image_file="${prefix}_${year}_${image_file_ext}_${pos}.jpg"
         # use maxpos instead..
         typeset image_file="${prefix}_${year}_${maxpos}.jpg"
       }

       [ -f "$image_file" ] && { let skipcnt="(( $skipcnt + 1 ))"; continue; }

       full="$year $pos $good_id"
       start=$(date +%s)
       wget -T "${timeout}" -q -O "${image_file}" "$full_url"
       rc=$?
       end=$(date +%s)
       let elapsed="(( $end - $start ))"
       typeset msg="$full Elapsed $elapsed rc: $rc filename= ${image_file}"

       log "main image: $msg"
       echo "$msg"
     done
   done
 done

 [ "$skipcnt" -ne 0 ] && { log "main skipcnt="$skipcnt; }
}

## ENV ##

years="1809"
urls="
http://dl.antenati.san.beniculturali.it/v/Archivio+di+Stato+di+Pescara/Stato+civile+napoleonico/Elice/Matrimoni+processetti/1809/6395/
http://dl.antenati.san.beniculturali.it/v/Archivio+di+Stato+di+Pescara/Stato+civile+napoleonico/Elice/Matrimoni+processetti/1809/6395/?g2_page=2
http://dl.antenati.san.beniculturali.it/v/Archivio+di+Stato+di+Pescara/Stato+civile+napoleonico/Elice/Matrimoni+processetti/1809/6395/?g2_page=3
http://dl.antenati.san.beniculturali.it/v/Archivio+di+Stato+di+Pescara/Stato+civile+napoleonico/Elice/Matrimoni+processetti/1809/6395/?g2_page=4
http://dl.antenati.san.beniculturali.it/v/Archivio+di+Stato+di+Pescara/Stato+civile+napoleonico/Elice/Matrimoni+processetti/1809/6395/?g2_page=5
http://dl.antenati.san.beniculturali.it/v/Archivio+di+Stato+di+Pescara/Stato+civile+napoleonico/Elice/Matrimoni+processetti/1809/6395/?g2_page=6
"
timeout="90"
type="Matrimoni+processetti"
prefix="processetti"
place="Elice"
province="Pescara"
#group="Stato+civile+della+restaurazione"
group="Stato+civile+napoleonico"
#group="Stato+civile+italiano"
base_site="http://dl.antenati.san.beniculturali.it"
base_year="${base_site}/v/Archivio+di+Stato+di+${province}/${group}/"

# Logging
today="$(date +%d%m%y)"
log="${prefix}_${today}.log"

# Photos
max_photos=300

## MAIN ##

 main $years

## EOF ##
