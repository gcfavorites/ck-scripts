
encoding system utf-8
::ck::require cmd   0.6
::ck::require http  0.2
::ck::require strings 0.6

namespace eval httputils {
    variable version 1.2
    variable author  "Chpock <chpock@gmail.com>"
    variable editor  "kns @ RusNet"

    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
}
proc ::httputils::init {} {

  cmd register httphead ::httputils::httphead \
    -bind "http" -bind "server" -bind "сервер" -autousage -doc "http"

  cmd doc "http" {~*!http* <url>~ - получить информацию об URL.}

  msgreg {
    err  &nError&K(&R%s&K)&n while request url&K(&B%s&K):&r %s&n.
    hh.main &K[&nHTTP &B%s&n %s&K]&n %s
    hh.size &nSize&K:&c %s&n bytes
    hh.file &nFile&K:&c %s
    hh.loc  &nLocation&K:&B %s
    hh.serv &nServer&K:&B %s
    hh.join "&K; "
    hh.noinfo &nNo usefull information on url &B%s
  }
}
proc ::httputils::httphead { sid } {
  session import

  if { $Event == "CmdPass" } {
    session set ReqUrl [join [lrange $StdArgs 1 end] " "]
    http run $ReqUrl -head -mark "Head"
    return
  }

  if { $Mark eq "Head" } {
    if { $HttpStatus < 0 } {
      reply -err err $HttpStatus $HttpUrl $HttpError
    }
    set file ""
    set serv ""
    set xpow [list]
    set istext 0
    foreachkv $HttpMeta {
      switch -- $k {
	"Content-Type" {
	  if { [string match -nocase "text/html*" $v] } {
	    set istext 1
	  }
	}
	"Content-Disposition" {
	  foreach_ [split $v {;}] {
	    set_ [split [string trim $_] =]
	    if { [lindex $_ 0] != "filename" } continue
	    set file [string trim [join [lrange $_ 1 end] =] "\""]
	  }
	}
	"Server" {
	  append serv $v " "
	}
	"X-Powered-By" {
	  lappend xpow $v
	}
      }
    }


    set_ [list [cformat hh.main $HttpMetaCode $HttpMetaMessage $HttpMetaType]]
    if { $HttpMetaLength != "" } { lappend_ [cformat hh.size $HttpMetaLength] }
    if { $file != "" } { lappend_ [cformat hh.file $file] }
    if { $HttpMetaLocation != "" } { lappend_ [cformat hh.loc $HttpMetaLocation] }
    foreach x $xpow {
      if { [string first $x $serv] != -1 } continue
      append serv $x " "
    }
    set serv [string trim $serv]
    if { $serv != "" } { lappend_ [cformat hh.serv $serv] }

    if { [llength_] } {
      reply -uniq [cjoin $_ hh.join]
    } {
      reply -uniq hh.noinfo $HttpUrl
    }
  }
}

::httputils::init