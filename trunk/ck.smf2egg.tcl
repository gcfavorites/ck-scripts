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

proc ::smfegg::parse { data } {

    set data [[namespace current]::xml_list_create [string stripspace $data]]

    set path [[namespace current]::xml_join_tags [list 0 "smf:xml-feed"] [list] -1 "recent-post"]
    set count [[namespace current]::xml_get_info $data $path]

    set tmp [list]

    for {set i 0} {$i < $count} {incr i} {
        foreach_    [list "time" "subject" "body" "link" \
                            [list "starter" 0 "name"] [list "poster" 0 "name"] \
                            [list "topic" 0 "subject"] [list "board" 0 "name"] \
                    ] {
            set ttmp([lindex $_ 0]) [lindex [join [[namespace current]::cookie_replace [concat [list 0 "smf:xml-feed" $i "recent-post" 0] $_] $data]] 1]
        }
        lappend tmp [array get ttmp]
        unset ttmp _
    }

#    debug $tmp

    unset data path count i

    return $tmp
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

#
# XML Functions
##

proc ::smfegg::xml_list_create {xml_data} {
    set xml_list [list]
    set ns_current [namespace current]

    set ptr 0
    while {[set tag_start [${ns_current}::xml_get_position $xml_data $ptr]] != ""} {
        set tag_start_first [lindex $tag_start 0]
        set tag_start_last [lindex $tag_start 1]

        set tag_string [string range $xml_data $tag_start_first $tag_start_last]

        # move the pointer to the next character after the current tag
        set last_ptr $ptr
        set ptr [expr { $tag_start_last + 2 }]

        array set tag [list]
        # match 'special' tags that dont close
        if {[regexp -nocase -- {^!(\[CDATA|--|DOCTYPE)} $tag_string]} {
            set tag_data $tag_string

            regexp -nocase -- {^!\[CDATA\[(.*?)\]\]$} $tag_string -> tag_data
            regexp -nocase -- {^!--(.*?)--$} $tag_string -> tag_data

            if {[info exists tag_data]} {
                set tag(data) [${ns_current}::xml_escape $tag_data]
            }
        } else {
            # we should only ever encounter opening tags, if we hit a closing one somethings wrong
            if {[string match {[/]*} $tag_string]} {
                putlog "\002RSS Malformed Feed\002: Tag not open: \"<$tag_string>\" ($tag_start_first => $tag_start_last)"
                continue
            }

            # split up the tag name and attributes
            regexp -- {(.[^ \/\n\r]*)(?: |\n|\r\n|\r|)(.*?)$} $tag_string -> tag_name tag_args
            set tag(name) [${ns_current}::xml_escape $tag_name]

            # split up all of the tags attributes
            set tag(attrib) [list]
            if {[string length $tag_args] > 0} {
                set values [regexp -inline -all -- {(?:\s*|)(.[^=]*)=["'](.[^"']*)["']} $tag_args]

                foreach {r_match r_tag r_value} $values {
                    lappend tag(attrib) [${ns_current}::xml_escape $r_tag] [${ns_current}::xml_escape $r_value]
                }
            }
#"##
            # find the end tag of non-self-closing tags
            if {(![regexp {(\?|!|/)(\s*)$} $tag_args]) || \
                (![string match "\?*" $tag_string])} {
                set tmp_num 1
                set tag_success 0
                set tag_end_last $ptr

                # find the correct closing tag if there are nested elements
                #  with the same name
                while {$tmp_num > 0} {
                    # search for a possible closing tag
                    set tag_success [regexp -indices -start $tag_end_last -- "</$tag_name>" $xml_data tag_end]

                    set last_tag_end_last $tag_end_last

                    set tag_end_first [lindex $tag_end 0]
                    set tag_end_last [lindex $tag_end 1]

                    # check to see if there are any NEW opening tags within the
                    #  previous closing tag and the new closing one
                    incr tmp_num [regexp -all -- "<$tag_name\(|.\[^>\]+\)>" [string range $xml_data $last_tag_end_last $tag_end_last]]

                    incr tmp_num -1
                }

                if {$tag_success == 0} {
                    putlog "\002RSS Malformed Feed\002: Tag not closed: \"<$tag_name>\""
                    return
                }

                # set the pointer to after the last closing tag
                set ptr [expr { $tag_end_last + 1 }]

                # remember tag_start*'s character index doesnt include the tag start and end characters
                set xml_sub_data [string range $xml_data [expr { $tag_start_last + 2 }] [expr { $tag_end_first - 1 }]]

                # recurse the data within the currently open tag
                set result [${ns_current}::xml_list_create $xml_sub_data]

                # set the list data returned from the recursion we just performed
                if {[llength $result] > 0} {
                    set tag(children) $result

                # set the current data we have because we're already at the end of a branch
                #  (ie: the recursion didnt return any data)
                } else {
                    set tag(data) [${ns_current}::xml_escape $xml_sub_data]
                }
            }
        }


### CHANGED

#        debug "\"$xml_data\""

        # insert any plain data that appears before the current element
        if {($last_ptr != [expr { $tag_start_first - 1 }]) \
                && ([string trim [set tmp [${ns_current}::xml_escape [string range $xml_data $last_ptr [expr { $tag_start_first - 2 }]]]]] ne "")} {
            lappend xml_list [list "data" $tmp]
            unset tmp
        }

        # inset tag data
        lappend xml_list [array get tag]

        unset tag
    }

    # if there is still plain data left add it
    if {$ptr < [string length $xml_data]} {
        lappend xml_list [list "data" [${ns_current}::xml_escape [string range $xml_data $ptr end]]]
    }

    return $xml_list
}

# simple escape function
proc ::smfegg::xml_escape {string} {
    regsub -all -- {([\{\}])} $string {\\\1} string

    return $string
}

# this function is to replace:
#  regexp -indices -start $ptr {<(!\[CDATA\[.+?\]\]|!--.+?--|!DOCTYPE.+?|.+?)>} $xml_data -> tag_start
# which doesnt work correctly with tcl's re_syntax
proc ::smfegg::xml_get_position {xml_data ptr} {
    set tag_start [list -1 -1]

    regexp -indices -start $ptr {<(.+?)>} $xml_data -> tmp(tag)
    regexp -indices -start $ptr {<(!--.*?--)>} $xml_data -> tmp(comment)
    regexp -indices -start $ptr {<(!DOCTYPE.+?)>} $xml_data -> tmp(doctype)
    regexp -indices -start $ptr {<(!\[CDATA\[.+?\]\])>} $xml_data -> tmp(cdata)

    # 'tag' regexp should be compared last
    foreach name [lsort [array names tmp]] {
        set tmp_s [split $tmp($name)]
        if {( ([lindex $tmp_s 0] < [lindex $tag_start 0]) && \
              ([lindex $tmp_s 0] > -1) ) || \
            ([lindex $tag_start 0] == -1)} {
            set tag_start $tmp($name)
        }
    }

    if {([lindex $tag_start 0] == -1) || \
        ([lindex $tag_start 1] == -1)}  {
        set tag_start ""
    }

    return $tag_start
}

# returns information on a data structure when given a path.
#  paths can be specified using: [struct number] [struct name] <...>
proc ::smfegg::xml_get_info {xml_list path {element "data"}} {
    set i 0

    foreach {t_data} $xml_list {
        array set t_array $t_data

        # if the name doesnt exist set it so we can still reference the data
        #  using the 'stuct name' *
        if {![info exists t_array(name)]} {
            set t_array(name) ""
        }

        if {[string match -nocase [lindex $path 1] $t_array(name)]} {

            if {$i == [lindex $path 0]} {
                set result ""

                if {([llength $path] == 2) && \
                    ([info exists t_array($element)])} {
                    set result $t_array($element)
                } elseif {[info exists t_array(children)]} {
                    # shift the first path reference of the front of the path and recurse
                    set result [[namespace current]::xml_get_info $t_array(children) [lreplace $path 0 1] $element]
                }

                return $result
            }

            incr i
        }

        unset t_array
    }

    if {[lindex $path 0] == -1} {
        return $i
    }
}

# converts 'args' into a list in the same order
proc ::smfegg::xml_join_tags {args} {
    set list [list]

    foreach tag $args {
        foreach item $tag {
            if {[string length $item] > 0} {
                lappend list $item
            }
        }
    }

    return $list
}

#-------------

#
# Cookie Parsing Functions
##

proc ::smfegg::cookie_replace {cookie data} {
    set element "children"

    set tags [list]
    foreach {num section} $cookie {
        if {[string equal "=" [string range $section 0 0]]} {
            set attrib [string range $section 1 end]
            set element "attrib"
            break
        } else {
            lappend tags $num $section
        }
    }

    set return [[namespace current]::xml_get_info $data $tags $element]

    if {[string equal -nocase "attrib" $element]} {
        array set tmp $return

        if {[catch {set return $tmp($attrib)}] != 0} {
            return
        }
    }

    return $return
}

#--------------

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
        set body [string trimright [string range $body 0 197] [list "." " " "," ":" ";"]]
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
