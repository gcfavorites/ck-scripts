encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::soft {
    variable version 0.1
    variable OriginalAuthor "Vertigo@RusNet"
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::soft::init {  } {

    cmd register soft [namespace current]::run -doc "soft" -autousage \
        -bind "soft" -bind "софт"

    cmd doc "soft" {~*!soft* [-число] [-exact] <название>~ - поиск программ на сайте softodrom.ru.}

    config register -id "seealso" -type bool -default 0 \
        -desc "Enable \"seealso\" string." -access "n" -folder "soft"

    config register -id "showres" -type int -default 30 \
        -desc "Maximum results <5|10|30|50|100|300|500>." -access "n" -folder "soft"

    msgreg {
        err.http            &BОшибка связи с сайтом&K:&R %s
        err.notfound        ничего не найдено.
        soft.num            "&K[&B%s&K/&b%s&K]&n "
        main                %s%s
        main.date           %s
        main.descr          %s
        main.name           &L%s&L
        main.os             %s
        main.rus            &KРус.&n:&r %s
        main.section        &U%s&U
        main.size           %s
        main.type           &c&U%s&U
        main.url            &K## &U&b%s
        main.seealso        Всего найдено %s: %s&n.
        res.join            "&n - "
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


        if {[regexp {^-?(\d+).*} $Text -> num]} {
            set num [scan $num %d]
#            debug "num: $num"
            set Text [join [lrange [split $Text] 1 end]]
            unset ->
        }

        if {[lindex [split $Text] 0] eq "-exact"} {
            lappend query "exact" "on"
            set Text [join [lrange [split $Text] 1 end]]
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

        foreach {k v} $HttpMeta {
            debug -debug "k(%s) v(%s)" $k $v
        }

#        debug $HttpUrl

        set HttpData [string stripspace [encoding convertfrom cp1251 $HttpData]]

        set reg ""; # init

#++ regexp
        append reg {<div class="prgentry">}; # start
        append reg {<a class="subheader" href="([^\"]+)">}; # link
        append reg {([^<]+)</a>}; # name
        append reg {\s*(?:<img[^<]+>)?\s*?(?:\s<font class="[^\"]+"><i>[^<]+</i></font>)?(?:<span class="smark">[^<]+</span>)?}; # awards (probably too much expressions)
        append reg {\s*<br />([^<]+)<br />}; #description
        append reg {<span class="date"><span style="color: #fe7e02;">&raquo;</span>}; # arrow
        append reg {\s*<a href="[^\"]+">([^<]+)</a>\s}; # category
        append reg {-\s<a href="[^\"]+">([^<]+)</a>\s}; # subcategory
        append reg {-\s(\S+)\s}; # date
        append reg {-\s*(\S+\s\S+|n/a|\s)\s*}; # size
        append reg {-\s(\S+)}; # OS
        append reg {[^:]+:\s(\S+)\s}; # rus. tr.
        append reg {-\s<a[^>]+>([^<]+</a>[^<]*)</span>}; # status
        append reg {<br /><hr[^>]+></div>}; # end

        # full regexp (05.04.2009)
        ## set reg {<div class="prgentry"><a class="subheader" href="([^\"]+)">([^<]+)</a>\s*(?:<img[^<]+>)?\s*?(?:\s<font class="[^\"]+"><i>[^<]+</i></font>)?(?:<span class="smark">[^<]+</span>)?\s*<br />([^<]+)<br /><span class="date"><span style="color: #fe7e02;">&raquo;</span>\s*<a href="[^\"]+">([^<]+)</a>\s-\s<a href="[^\"]+">([^<]+)</a>\s-\s(\S+)\s-\s*(\S+\s\S+|n/a|\s)\s*-\s(\S+)[^:]+:\s(\S+)\s-\s<a[^>]+>([^<]+</a>[^<]*)</span><br /><hr[^>]+></div>}
        #
#-- regexp

        set HttpData [regexp -all -inline -- $reg $HttpData]

#        debug -info $HttpData

        if {[set len [expr {[llength $HttpData] / 10 }]]} {
            set list [list]

            foreach {-> url name descr section subcat date size os rus type} $HttpData {
                lappend list    [list \
                                    "name" $name "descr" $descr "section" $section \
                                    "date" $date "size" $size "os" $os \
                                    "rus" $rus "type" $type "url" $url \
                                ]
            }

            if {$num < 1} { set num 1 }
            if {$num > [llength $list]} {set num [llength $list]}
            if {$len > 1} {set c [cformat "soft.num" $num $len]} {set c ""}

            set_ [list]
            array set tmp [parse [lindex $list [expr {$num -1}]]]

            foreach v [list "name" "descr" "section" "date" "size" "os" "rus" "type" "url"] {
                if {[string trim $tmp($v)] ne ""} {
                    lappend_ [cformat "main.${v}" $tmp($v)]
                }
            }

            reply -noperson main $c [cjoin $_ "res.join"]

            unset _ -> url name descr section date size os rus type num len c k v tmp reg


            if {[config get "seealso"]} {
                set_ [list]
                foreach tmp $list {
                    lappend_ [lindex $tmp 1]
                }
                reply -multi "main.seealso" [llength $_] [cjoin $_ "seealso.join"]

                unset _ tmp
            }

        } else {
            reply -err notfound
        }
    }

    return
}

proc ::soft::parse { list } {
    array set tmp $list

    if {[string length $tmp(descr)] > 100} {
        set tmp(descr) [string trimright [string range $tmp(descr) 0 97] [list "." " " "," ":" ";"]]
        append tmp(descr) "..."
    }

    set tmp(size) [string trim [string map [list "n/a" ""] $tmp(size)]]
    set tmp(type) [string trim [string map [list "n/a" "" "</a>" ""] $tmp(type)]]

    unset list

    return [array get tmp]
}

::soft::init
