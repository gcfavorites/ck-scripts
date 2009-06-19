encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::w3org {
    variable version 0.2
    variable OriginalAuthor "Xam <xam@egghelp.ru>"
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http

}

proc ::w3org::init {  } {

    cmd register w3org [namespace current]::run -doc "w3org" -autousage \
        -bind "w3org" -bind "w3c"

    cmd doc "w3org" {~*!w3c* [-enc codepage] <url>~ - проверка странички на валидность.}

    msgreg {
        err.http        &BОшибка связи с сайтом&K:&R %s
        err.cant        Sorry! This document can not be checked.
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

        set args [lrange $StdArgs 1 end]
        getargs -enc str ""
        set Text [lindex $args 0]

        if {([string length $Text] < 3) \
                || ([string first "." $Text] == -1)} {
            reply weird
            return
        }

        regsub -nocase -- {^http://} $Text "" Text

        array set query [list]

        set query(uri) "http://${Text}"
        set query(charset) "(detect automatically)"
        set query(doctype) "Inline"
        set query(group) "0"

        if {![string is space $(enc)]} {set query(charset) $(enc)}


        http run "http://validator.w3.org/check" \
                -post \
                -query [array get query] \
                -mark "Start" \
                -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1"

        unset query args
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


        if {[string first "Sorry! This document can not be checked." $HttpData] != -1} {
            reply -err cant
        } elseif {[regexp -- \
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

        } else {
            reply -err "Ошибка"
        }
    }

    return
}

::w3org::init
