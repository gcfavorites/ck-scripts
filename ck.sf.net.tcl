encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::sfnet {
    variable version 0.1
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
                        "words" $Text "offset" $num "sort" "score" \
                        "limit" "1" "sortdir" "desc" "type_of_search" "soft" \
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

        set HttpData [string stripspace $HttpData]

#        debug $HttpData

        regexp -- {\s*Results\s*<strong>(\d+)&nbsp;-&nbsp;\d+</strong>\s*of\s*(\d+)\s*} $HttpData -> num of

        if {[regexp -- {<td class="project">\s*<h2><a href="([^\"]+)">([^<]+)</a></h2>\s*</td>} $HttpData -> url name] \
                && [regexp -- {<td>\s*<h3><a href="/project/stats/rank_history\.php\?group_id=[^\"]+">([^<]+)</a></h3>\s*</td>\s*<td>\s*(.*?)\s*</td>\s*<td>\s*(.*?)\s*</td>\s*<td>\s*(\S+)\s*</td>} $HttpData -> rank registered latest downloads] \
                && [regexp -- {<td colspan="6" class="description">(.*?)<p>\s*<a href="/project/memberlist\.php} $HttpData -> desc]} {

            if {$of > 1} {set c [cformat "sfnet.num" $num $of]} {set c ""}

            reply -noperson main \
                $c \
                [string trim [string stripspace [html unspec $name]]] \
                "http://sourceforge.net${url}" \
                [string trim [string stripspace [html unspec [html untag $desc]]]] \
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
