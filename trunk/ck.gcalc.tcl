encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::gcalc {
    variable version 0.1
    variable OriginalAuthor "Vertigo@RusNet"
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::gcalc::init {  } {

    cmd register gcalc [namespace current]::run -doc "gcalc" -autousage \
        -bind "gcalc" -bind "gc"

    cmd doc "gcalc" {~*!gcalc* <выражение>~ - запрос к Google-калькулятору.}

    msgreg {
        err.http		&BОшибка связи с сайтом&K:&R %s
        main			%s
    }
}


proc ::gcalc::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

		set Text [join [lrange $StdArgs 1 end]]

		debug -info $Text

		http run "http://www.google.com/search" \
				-query [list q $Text hl ru num 1] \
				-mark "Start" \
				-useragent "Opera/9.80 (Windows NT 5.1; U; en) Presto/2.2.15 Version/10.00"

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
        
#        debug -info $HttpData
		regsub -all -- {<sup>([^<]+)</sup>} $HttpData {^\1} HttpData
		regsub -all -- {<font[^>]*>([^<]+)</font>} $HttpData {\1} HttpData
		set HttpData [string map {&#215; *} $HttpData]
		
		if {[regexp -- {<img src=/images/calc_img\.gif[^>]*><td>&nbsp;<td nowrap ><h2[^>]*><b>([^<]+)</b></h2><tr><td>} $HttpData - res]} {
			reply main  [html unspec [html untag $res]]
		} else {
			reply -err "Ничего"
		}
		
    }

    return
}

::gcalc::init
