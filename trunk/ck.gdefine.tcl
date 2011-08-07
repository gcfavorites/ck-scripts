encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::gdefine {
    variable version 0.1
    variable OriginalAuthor "Vertigo@RusNet"
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::gdefine::init {  } {

    cmd register gdefine [namespace current]::run -doc "gdefine" -autousage \
        -bind "gdefine" -bind "define" -bind "def"

    cmd doc "gdefine" {~*!define* [-номер] <слово>~ - запрос к Google.}

    msgreg {
        err.http		&BОшибка связи с сайтом&K:&R %s
        
        gdefine.num            "&K[&B%s&K/&b%s&K]&n"
        gdefine.main1			%s — %s
        gdefine.main2			%s %s — %s
    }
}


proc ::gdefine::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

		set Text [join [lrange $StdArgs 1 end]]
        set num 1

		debug -info $Text
		
		if {[regexp -- {^-?(\d+)\s*(.*)\s*$} $Text -> num Text]} {
            set num [scan $num %d]
#            debug "num: $num; Text: $Text"
            unset ->
        }
        
        if {$Text ne ""} {

            session set num $num
            session set Text $Text

			http run "http://www.google.com/search" \
					-query [list q "define: $Text" hl ru num 1] \
					-mark "Start" \
					-useragent "Opera/9.80 (Windows NT 5.1; U; en) Presto/2.6.30 Version/10.61"
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
        
#        debug -info $HttpData
        
        set l [list]
        
        foreach {_ _} [regexp -all -inline -- {<ul type="disc" class=std>(.*?)</ul>} $HttpData] {
#        	debug -info "$_\n\n====\n"
			set data [string map [list "<li>" "\n<li>"] $_]
			foreach - [split $data \n]  {
				if {[regexp -- {^<li>\s*(.*?)\s*<br>.*font color=#008000>([^<]+)</font></a><p>} ${-} - def link]} {
					set def [string map {{́} {}} $def]
		        	lappend l "$def @ http://${link}"
		        } elseif {[regexp -- {^<li>\s*(.*?)\s*<br>} ${-} - -] \
		        				|| [regexp -- {^<li>\s*(.*?)\s*$} ${-} - -]} {
		        	lappend l ${-}
		        }
			}
        }
        
        set ldata [llength $l]
        
        if {$ldata == 0} {
        	reply Ничего
        } elseif {$ldata == 1} {
        	reply -noperson "gdefine.main1" $Text [html unspec [html untag [lindex $l 0]]]
      	} else {
            if {[incr num -1] >= $ldata} {set num [expr {$ldata - 1}]}
      
	        reply -noperson "gdefine.main2" [cformat "gdefine.num" [expr {$num + 1}] $ldata] $Text [html unspec [html untag [lindex $l $num]]]
		}
        
    }

    return
}

::gdefine::init
