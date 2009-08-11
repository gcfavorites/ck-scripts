encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::sfnet {
    variable version 0.2
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::sfnet::init {  } {

    cmd register sfnet [namespace current]::run -doc "sfnet" -autousage \
        -bind "sf"

    cmd doc "sfnet" {~*!sf* [-число] <название>~ - поиск проектов на sf.net.}

    msgreg {
        err.http            &BОшибка связи с сайтом&K:&R %s
        err.notfound        ничего не найдено.
        sfnet.num           "&K[&B%s&K/&b%s&K]&n "
        main                %s&r%s&n :: &B&U%s&U&n :: %s :: Rank:&g %s&n.
    }
}


proc ::sfnet::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        set Text [join [lrange $StdArgs 1 end]]
        set num 1


        if {[regexp {^-?(\d+).*} $Text -> num]} {
            set num [scan $num %d]
#            debug "num: $num"
            set Text [join [lrange [split $Text] 1 end]]
            unset ->
        }

        if {$Text ne ""} {

            if {$num < 1} {set num 1}
            incr num -1

#            debug "$Text :: $num"

            set query   [list \
                            "words" $Text "offset" $num "limit" "1" \
                            "sortdir" "desc" "type_of_search" "soft" \
                            "pmode" "0" "Search" "Search" \
                        ]

            http run "http://sourceforge.net/search/" \
                    -query $query \
                    -mark "Start" \
                    -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1" \
                    -heads [list "Referer" "http://sourceforge.net/search/"]

            unset query num
        } else {
            replydoc "sfnet"
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

#        set HttpData [string stripspace $HttpData]

#        debug $HttpUrl
        set reg {<td class="project">\s*<h2><a href="([^\"]+)">([^<]+)</a></h2>\s*</td>\s*}
        append reg {<td class="select">\s*<div[^>]*>([^<]+)</div>\s*</td>\s*}
        append reg {<td>\s*([^%]+%)\s*</td>\s*}
        append reg {<td>\s*<a href="([^\"]+)">([^<]+)</a>\s*</td>\s*}
        append reg {<td>\s*(\d{4}-\d{2}-\d{2})\s*</td>\s*}
        append reg {<td>\s*(\d{4}-\d{2}-\d{2}|<span.*?</span>)\s*</td>\s*}
        append reg {<td>\s*(\S+)\s*</td>\s*</tr>\s*}
        append reg {<tr>\s*<td colspan="6" class="description">(.*?)<ul class="hide" id="meta0_1">}

#        debug [regexp -all -inline -- $reg $HttpData]

        if {[regexp -- $reg $HttpData - url name rel act rurl rank registered latest downloads desc]} {

            if {![regexp -- {<div class="yui-u first">\s*Results\D+(\d+)[^<]*<\D+(\d+)\s*</div>} $HttpData -> num of]} {
                set num [set of 1]
            }

            if {$of > 1} {set c [cformat "sfnet.num" $num $of]} {set c ""}


            reply -noperson main \
                $c \
                [string trim [html unspec $name]] \
                "http://sourceforge.net${url}" \
                [string trim [html unspec [html untag $desc]]] \
                $rank

#            unset _ -> url name descr section date size os rus type num len c k v tmp reg
        } else {
#            debug -err "хуй"
            reply -err notfound
        }

##+
    if 0 {
        foreach_ [list url name rank registered latest downloads desc] {
            debug "${_}: [set $_]"
        }
    }
##-
    }
    return
}

::sfnet::init
