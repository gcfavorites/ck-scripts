encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require cache

namespace eval ::smfegg {
    variable version 0.2
    variable author "kns@RusNet"

    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html
    namespace import -force ::ck::cache::cache
}


proc ::smfegg::init {  } {

    cmd register smfegg [namespace current]::run -doc "smfegg" \
        -bindpub "last"

    cmd doc "smfegg" {~*!last*~ - последнее сообщение на форуме.}

    config register -id "period" -default 4m -type time \
        -desc "Update interval." -access "n" -folder "smfegg" -hook chkconfig

    config register -id "site" -type list -default "" \
        -desc "Forum for monitoring." -access "n" -folder "smfegg"

    etimer -norestart -interval [config get "period"] "smfegg.update" [namespace current]::checkupdate
    cache register -nobotnet -nobotnick -maxrec 30 -ttl 0

    msgreg {
        err.http    &BОшибка связи с сайтом&K:&R %s
        err.parse   &BОшибка обработки результатов поиска.
        err.nofound &RПо Вашему запросу ничего не найдено.
        top         "&L&K:&L:&n &b&U%s&n &K:&L:&L:&n Топик:&B %s&n &K:&L:&L:&n Автор:&p %s&n &K:&L:&n Кратко:&g %s&n &K:&L:&L:&n Форум:&B %s &n&K:&L:&L:&n Дата:&r %s&n &K:&L:&L&n"
    }
}

proc ::smfegg::run { sid } {
    variable datafile

    session import

    set site [config get "site" "smfegg"]

    if {$site eq ""} {
        debug -err "Set the \"smfegg.site\" parameter, please."
        return
    }

    if {![regexp -nocase -- {(http://[^\/]+)} $site -> site]} {
        set site "http://$site"
    }

    set site [string trimright $site "\/"]

#    debug -info "site: $site"

    cache makeid [lindex [regexp -inline -- {http://(www\.)?([^\/]+)} $site] end]

    if { ![cache get data] } {
        set data [list]
    }

    if { $Event == "CmdPass" } {

        if {![llength $data]} {
            reply -private "Datafile is empty. We really sorry."
            return
        }

        set Text [join [lrange $StdArgs 1 end]]

        set num 1

        if {[regexp {^-?(\d+)$} [lindex $StdArgs 1] -> num]} {
            set num [scan $num %d]
#            debug -info "num: $num"
        }

        if {$num < 1} { set num 1 }
        if {$num > [llength $data]} {set num [llength $data]}

        set datafile [frmt $sid [lindex $data [expr {$num - 1}]]]

        reply -private $datafile
    }

    if { $CmdEventMark eq "Announce" } {
        if {![llength $data]} {
            debug -err "Datafile is empty."
            return
        }

        session set CmdReplyParam [list "-noperson" "-broadcast"]

#        debug -info [lindex $data 0]

        set datafile [frmt $sid [lindex $data 0]]

        reply $datafile
    }

    return
}

proc ::smfegg::lefttofirst {pt ustr} {
    if {[set end [string first $pt $ustr]] == -1} {
        set end "end"
    } else {
        incr end -1
    }

    return [string range $ustr 0 $end]
}

proc ::smfegg::rightfromfirst {pt ustr} {
    if {[set start [string first $pt $ustr]] == -1} {
        set start "0"
    } else {
        incr start [string length $pt]
    }

    return [string range $ustr ${start} end]
}

proc ::smfegg::parse {ustr} {

 	set newlist [list]

	set ustr [string stripspace $ustr]

    while {[string match "*<recent-post>*</recent-post>*" $ustr]} {
        set tmp [rightfromfirst "<recent-post>" $ustr]
        set tmp [lefttofirst "</recent-post>" $tmp]
        array set tlist [list]
        foreach_ [list time id subject body starter poster topic board link] {
        	set $_ [lefttofirst "</${_}>" [rightfromfirst "<${_}>" $tmp]]
        	switch -exact -- $_ {
        		"starter" -
        		"poster" -
        		"board" {
        			set $_ [lefttofirst "</name>" [rightfromfirst "<name>" [set $_]]]
        		}

        		"topic" {
        			set $_ [lefttofirst "</subject>" [rightfromfirst "<subject>" [set $_]]]
        		}
        	}
        	
        	while {[regsub -- {<!\[CDATA\[(.*)\]\]>} [set $_] {\1} $_]} {continue}
        
            set tlist($_) [string trim [set $_]]
        }

        lappend newlist [array get tlist]
        unset tmp tlist
        set ustr [rightfromfirst "</recent-post>" $ustr]
    }

    return $newlist
}

proc ::smfegg::checkupdate { {sid ""} } {

    if { $sid eq "" } {
        session create -proc [namespace current]::checkupdate
        debug -debug "Created session for smfegg update."
        session event -return StartUpdate
    }
    session import

    if { $Event eq "StartUpdate" } {

        set site [config get "site" "smfegg"]

        if {$site eq ""} {
            debug -err "Set the \"smfegg.site\" parameter, please."
            return
        }

        if {![regexp -nocase -- {(http://[^\/]+)} $site -> site]} {
            set site "http://$site"
        }

        set site [string trimright $site "\/"]

#        debug -info "site: $site"

        http run "${site}/index.php" \
                -query [list "action" ".xml"] \
                -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1" \
                -return
    }

    if { $HttpStatus < 0 } {
        debug -err "while getting last quotes. (${HttpUrl})"
        return
    }

    set HttpData [parse $HttpData]

#    debug -info $HttpUrl

    if { ![llength $HttpData] } {
        debug -err "while parse page with last posts."
        return
    }

    set_ [lindex [regexp -inline -- {http://(www\.)?([^\/]+)} $HttpUrl] end]

    cache makeid $_
    set bc 0

    if { [cache get data] } {
        array set tmp [lindex $HttpData 0]
        array set ttmp [lindex $data 0]

        if {($tmp(subject) eq $ttmp(subject)) && ($ttmp(link) eq $ttmp(link))} {
            return
        } else {
            set bc 1
        }
        unset tmp ttmp
    } else {
        set bc 1
    }

    cache put $HttpData


    if {$bc} {
        debug -info "announce posts"
        cmd invoke -pub -cmdid "smfegg" -mark "Announce"
    }

#    debug -info $HttpData
    return
}

proc ::smfegg::frmt { sid ustr } {
    session import

    array set tmp $ustr

    set body $tmp(body)

#    debug "body before: $body"

    regsub -all -- {<img[^>]+>} $body "" body
    regsub -all -- {<div class="quoteheader">.+?</div>} $body "" body
    regsub -all -- {<div class="quote">.+?</div>} $body "\[\037цитата\037\] " body
    regsub -all -- {<div class="codeheader">.+?</div>} $body "" body
    regsub -all -- {<div class="code">.+?</div>} $body "\[\037код\037\] " body
    regsub -all -- {<table.+?</table>} $body "\[\037Таблица\037\] " body

    set body [string stripspace [html unspec [html untag $body]]]

#    debug "body after: $body"

    if {[string length $body] > 200} {
        set body [string trimright [string range $body 0 197] ". ,:;"]
        append body "..."
    }

    set tmp(body) $body
    set tmp(subject) [string stripspace [html unspec $tmp(subject)]]
    set tmp(board) [string stripspace [html unspec $tmp(board)]]
    set tmp(topic) [string stripspace [html unspec $tmp(topic)]]

    foreachkv [array get tmp] {set tmp($k) [string trim $v]}

    set_    [cformat top $tmp(link) $tmp(subject) $tmp(poster) $tmp(body) $tmp(board) $tmp(time)]

    unset body tmp

    return $_
}

proc ::smfegg::chkconfig { mode var oldv newv hand } {
  if { ![string equal -length 3 $mode "set"] } return
  etimer -interval $newv "smfegg.update" ::smfegg::checkupdate
  return
}

::smfegg::init
