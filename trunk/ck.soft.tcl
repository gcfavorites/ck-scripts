encoding system utf-8
::ck::require cmd
::ck::require http

namespace eval ::soft {
    variable version 0.2
    variable OriginalAuthor "Vertigo@RusNet"
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
}

proc ::soft::init {  } {

    cmd register soft [namespace current]::run -doc "soft" -autousage \
        -bind "soft" -bind "софт"

    cmd doc "soft" {~*!soft* [-число] [-exact] <название>~ - поиск программ на сайте softodrom.ru.}

    config register -id "showres" -type int -default 30 \
        -desc "Maximum results <5|10|30|50|100|300|500>." -access "n" -folder "soft"

    msgreg {
        err.http            &BОшибка связи с сайтом&K:&R %s
        err.notfound        ничего не найдено.
        soft.num            "&K[&B%s&K/&b%s&K]&n "
        soft                %s&L%s&L %s - &U%s&U - %s - %s - %s - &KРус.&n:&r %s &n- &c&U%s&U &n- &K## &U&b%s&n
        main.seealso        Всего найдено %s.
        seealso.join        "&B,&n "
    }
}


proc ::soft::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        set Text [join [lrange $StdArgs 1 end]]
        set num 1
        set query   [list \
                        "where" "inprograms" "prog_searchindex" "descr" \
                        "news_searchindex" "descr" "news_intime" "0" \
                        "comm_inprogs" "on" "comm_innews" "on" "comm_intime" "0" \
                    ]


        if {[regexp -- {^-?(\d+)\s*(.*)\s*$} $Text -> num Text]} {
            set num [scan $num %d]
#            debug "num: $num; Text: $Text"
            unset ->
        }

        if {[regexp -- {^(?:-exact)\s*(.*)\s*$} $Text -> Text]} {
            lappend query "exact" "on"
#            debug "num: $num; Text: $Text"
            unset ->
        }

        if {$Text ne ""} {

            if {[lsearch [list "5" "10" "30" "50" "100" "300" "500"] [set showres [config get "showres"]]] == -1} {
                set showres 30
            }

            lappend query "showres" $showres
            lappend query "text" $Text

            session set num $num

            http run "http://www.softodrom.ru/scr/search.php" \
                    -query-codepage cp1251 \
                    -query $query \
                    -mark "Start" \
                    -charset "cp1251" \
                    -forcecharset \
                    -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1" \
                    -heads [list "Referer" "http://www.softodrom.ru/scr/search.php"]

            unset query showres
        } else {
            replydoc "soft"
        }
        return
    }

    if { $Mark eq "Start" } {

        if { $HttpStatus < 0 } {
            debug -err "Ошибка запроса '%s'." $HttpError
            reply -err "Ошибка запроса '%s'." $HttpError
            return
        }

        if {[regexp -- {<div class="prgentry">(.+?)<div class="google"} $HttpData - data]} {
            set data [split [string trim $data] \n]
            set ldata [llength $data]

            if {[incr num -1] >= $ldata} {set num [expr {$ldata - 1}]}

            set prog [parse [lindex $data $num]]

            if {[llength $prog]} {
#                debug [join $prog " . "]
                lassign $prog link name descr cat subcat date size os rus status

                if {$ldata > 0} {set c [cformat "soft.num" [incr num] $ldata]} {set c ""}

                reply -noperson soft $c $name $descr $cat $date $size $os $rus $status $link

            } else {
                reply -err "ошибка парсинга"
            }

            unset -
        }  else {
                reply -err notfound
        }
    }

    return
}

proc ::soft::parse { str } {

    regsub -all -- {<span[^<]*>[^<]*</span>} $str "" str
    regsub -all -- {</?(?:img|br|hr|span)[^<]*>} [string stripspace $str] "" str

    set reg ""; # init

#++ regexp
    append reg {<a class="subheader" href="([^\"]+)">}; # link
    append reg {([^<]+)</a>}; # name
    append reg {\s*([^<]+)}; #description
    append reg {<a href="[^\"]+">([^<]+)</a>}; # category
    append reg {\s*-\s<a href="[^\"]+">([^<]+)</a>}; # subcategory
    append reg {\s*-\s(\S+)}; # date
    append reg {\s*-([^-]*)-}; # size
    append reg {\s*(\S+)}; # OS
    append reg {[^:]+:\s(\S+)}; # rus. tr.
    append reg {\s*-\s<a[^>]+>([^<]+</a>[^<]*)</div>}; # status

    # full regexp (05.06.2009)
    ## set reg {<a class="subheader" href="([^\"]+)">([^<]+)</a>\s*([^<]+)\s*<a href="[^\"]+">([^<]+)</a>\s*-\s<a href="[^\"]+">([^<]+)</a>\s*-\s(\S+)\s*-[^-]*-\s*(\S+)[^:]+:\s(\S+)\s-\s<a[^>]+>([^<]+</a>[^<]*)</div>}
    #
#-- regexp

    if {[regexp -- $reg $str - link name descr cat subcat date size os rus status]} {
        if {[string length [set descr [string trim $descr]]] > 100} {
            set descr [string trimright [string range $descr 0 97] [list "." " " "," ":" ";"]]
            append descr "..."
        }

        if {[set size [string trim $size]] eq "n/a"} {set size "неизвестен"}
        set status [string map {</a> ""} $status]


        return [list $link $name $descr $cat $subcat $date $size $os $rus $status]
    }

    return [list]
}

::soft::init
