encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::tinyurl {
    variable version 0.1
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::tinyurl::init {  } {

    cmd register tinyurl [namespace current]::run -doc "tinyurl" -autousage \
        -bind "tinyurl" -bind "tiny" -bind "tyni"

    cmd doc "tinyurl" {~*!tiny* <ссылка>~ - формирование короткой ссылки.}

    msgreg {
        err.http                &BОшибка связи с сайтом&K:&R %s
        main                    &b&U%s&n
    }
}

proc ::tinyurl::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        set Text [string trim [lrange $StdArgs 1 end]]

		if {![string equal -nocase -length 7 "http://" $Text]} {
			set Text "http://${Text}"
		}

#        debug -info $Text

        http run "http://tinyurl.com/api-create.php" \
                -query [list "url" $Text] \
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

#        set HttpData [string stripspace $HttpData]

#        debug -info $HttpData

        if {$HttpData eq "ERROR"} {
            reply -err http
        } else {
            reply main $HttpData
        }
    }

    return
}

::tinyurl::init
