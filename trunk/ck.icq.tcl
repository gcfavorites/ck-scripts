encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::icqcheck {
    variable version 0.1
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::icqcheck::init {  } {

    cmd register icqcheck [namespace current]::run -doc "icqcheck" -autousage \
        -bind "icqcheck" -bind "icq"

    cmd doc "icqcheck" {~*!icq* <номер ICQ>~ - проверка номера ICQ на невидимость.}

    msgreg {
        err.http                &BОшибка связи с сайтом&K:&R %s
        err.st                  &BОшибка проверки статуса&K:&R %s&n.
        main                    Статус номера&B %s&n:&r %s&n.
    }
}


proc ::icqcheck::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        regsub -all -- {[^0-9]} [lindex $StdArgs 1] {} Text
        set Text [string trimleft $Text "0"]

        if {$Text ne ""} {

            set tmp [string length $Text]

            if {[expr {$tmp < 5}] || [expr {$tmp > 9}]} {
                reply -err "В номере ICQ должно быть 5-9 цифр."
                return
            }

 #           debug -info $Text

            set query [list]
            lappend query "human" "1" "uin" $Text
            if {[rand 2]} { lappend query "youwereadded" "on" }
            lappend query "uin4login" "" "password4login" "" "dN6VJ" "1"

#            debug -info "query: $query"

            http run "http://kanicq.ru/invisible/?method=2" \
                    -post \
                    -query $query \
                    -mark "Start" \
                    -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1" \
                    -heads [list "Referer" "http://kanicq.ru/invisible/?method=2"]
        } else {
            replydoc "icqcheck"
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

#        debug -info $HttpData

        if {![regexp -- \
                    {<div id="info">(.+?)</div>} \
                $HttpData -> HttpData]} {
            set HttpData "Ошибка парсинга"
        }

        if {[regexp -- {<strong>(\d+).*?(\S+)</strong>} $HttpData -> uin st]} {
            reply -noperson main $uin [html untag $st]
        } else {
            reply -err err.st [string stripspace [html unspec [html untag $HttpData]]]
        }
    }

    return
}

::icqcheck::init
