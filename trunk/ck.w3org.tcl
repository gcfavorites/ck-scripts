encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::w3org {
    variable version 0.1
    variable author "Xam <xam@egghelp.ru>"
    variable editor "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::w3org::init {  } {

    cmd register w3org [namespace current]::run -doc "w3org" -autousage \
        -bind "w3org" -bind "w3c"

    cmd doc "w3org" {~*!w3c* <url>~ - проверка странички на валидность.}

    msgreg {
        err.http        &BОшибка связи с сайтом&K:&R %s
        weird           "эта строка не похожа на правильный урл, попробуй еще раз ;)"
        main            %s&n.
        param           &K%s&n:&r %s
        url             &b&U%s&U
        res.join        "&n; "
    }
}


proc ::w3org::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        set Text [lindex $StdArgs 1]

        if {([string length $Text] < 3) \
                || ([string first "." $Text] == -1)} {
            reply weird
            return
        }

        set Text [string map -nocase [list "http://" ""] $Text]

        set Text [string map -nocase [list "\?" "%3F" "\#" "" "\&" "%26"] $Text]

        session set type [list [lindex $StdArgs 2]]

        http run "http://validator.w3.org/check" \
                -post \
                -query [list "uri" "http://${Text}"] \
                -mark "Start" \
                -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1"

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

        if {[regexp -- \
                    {<input type="text" id="uri" name="uri" value="([^\"]+)" size="50" />} \
                $HttpData -> url]} {

            set res [list]

            lappend res [cformat param "Url" [cformat url [string urldecode $url]]]

            if {[regexp -- {<th>Result:</th>\s*<[^>]+>\s*([^<]+)<} $HttpData -> ->]} {
                lappend res [cformat param "Result" [string trimright ${->}]]
            }


            foreach_ [list "Encoding" "Doctype"] {
                if {[regexp -- \
                            "${_}\[^:\]*:</th>\\\s*<td>(\[^<\]+)</td>" \
                        $HttpData -> ->]} {
                    lappend res [cformat param $_ ${->}]
                }
            }

            set res [cjoin $res res.join]

            reply -noperson -multi main $res

            unset _ -> res url

        }

    }

    return
}

::w3org::init
