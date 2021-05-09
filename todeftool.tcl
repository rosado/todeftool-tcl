namespace eval ToDefTool {
    variable dbclick
}

package require fileutil
package require Tk
package require BWidget

set event_lookup_indices [list]
set name_filter ""

proc reframeItemsDict {} {
    dict create Event [list] Sub [list] FX [list] CoFX [list]
}

set data_Event []
set data_Sub []
set data_FX []
set data_CoFX []

proc initReframeItemsVars {} {
    global data_Event data_Sub data_FX data_CoFX
    set data_Event []
    set data_Sub []
    set data_FX []
    set data_CoFX []
}

# will hold list of lists, where each list is of shape {key inline|var file_name line Event|FX|CoFX|Sub}
set reframe_data [list]
# each widget displaying a list of reframe items will use indices to lookup
# the actual data in `reframe_data`
set reframe_lookup_indices [reframeItemsDict]
set reframe_data_labels [reframeItemsDict]

#set index_build_executable "/usr/local/bin/reframe-tool"
set index_build_executable "/Users/roland/dev/reframe-nimble/reframe"
set index_build_args "index"
set index_build_directories "-r=test-data,"
# should be one of: "ok", "error"
set index_build_status ""
set index_build_status_message ""

proc eventDataStringToList {event_data_string} {
    return [lreplace [split $event_data_string \n] end end]
}

proc listFromFile {file} {
    return [lreplace [eventDataStringToList [fileutil::cat $file]] end end]
}

proc setBuildIndexStatus {status message} {
    global index_build_status index_build_status_message
    set index_build_status $status
    set index_build_status_message $message
}

proc rebuildDefinitionFile {directories} {
    global index_build_executable index_build_args index_build_status index_build_status_message
    set command_string "| $index_build_executable $index_build_args $directories "
    puts $command_string
    set io [open $command_string r]
    set output [read $io]
    if {[catch {close $io} err]} {
        # TODO: emit an event here
        setBuildIndexStatus "error" $err
        # TODO: put that in a window? + change status color to red
        puts $err
        return ""
    } else {
        setBuildIndexStatus "ok" ""
        return $output
    }
}

proc populateData {event_data_string} {
    global reframe_data reframe_lookup_indices reframe_data_labels
    global data_Event data_Sub data_FX data_CoFX
    set local_data [eventDataStringToList $event_data_string]
    set local_data [lsort -index 0 $local_data]

    foreach reframe_type {"Event" "Sub" "FX" "CoFX"} {
        set reframe_lookup_indices [dict replace $reframe_lookup_indices $reframe_type [list]]
        set reframe_data_labels [dict replace $reframe_data_labels $reframe_type [list]]
    }

    set index 0
    set event_lookup_indices [list]
    foreach event_info $local_data {
        set reframe_type [lindex $event_info 4]
        dict lappend reframe_lookup_indices $reframe_type $index
        dict lappend reframe_data_labels $reframe_type [lindex $event_info 0]

        incr index
    }

    foreach reframe_type_var {"Event" "Sub" "FX" "CoFX"} {
        set "data_$reframe_type_var" [dict get $reframe_data_labels $reframe_type_var]
    }
    
    set reframe_data $local_data
}

proc selectedReframeType {} {
    set m [dict create ".reframe_tabs.events" "Event" ".reframe_tabs.subs" "Sub" ".reframe_tabs.effects" "FX" ".reframe_tabs.coeffects" "CoFX"]
    set selected_tab [.reframe_tabs select]
    set reframe_type [dict get $m $selected_tab]
    return $reframe_type
} 

proc filterData {} {
    global reframe_data reframe_lookup_indices reframe_data_labels name_filter
    global data_Event data_Sub data_FX data_CoFX
    
    set reframe_type [selectedReframeType]
    #puts "REFRAME TYPE/TAB: $reframe_type / $selected_tab"

    set reframe_data_labels [dict replace $reframe_data_labels $reframe_type [list]]
    set reframe_lookup_indices [dict replace $reframe_lookup_indices $reframe_type [list]]

    set index 0
    foreach reframe_item $reframe_data {
        set item_type [lindex $reframe_item 4]
        if {$name_filter eq "" && $reframe_type eq $item_type} {
            dict lappend reframe_data_labels $reframe_type [lindex $reframe_item 0]
            dict lappend reframe_lookup_indices $reframe_type $index
        } elseif {[string match -nocase $name_filter [lindex $reframe_item 0]] && $reframe_type eq $item_type} {
            dict lappend reframe_data_labels $reframe_type [lindex $reframe_item 0]
            dict lappend reframe_lookup_indices $reframe_type $index
        }

        incr index
    }
    set "data_$reframe_type" [dict get $reframe_data_labels $reframe_type]
}

proc initializeDeftool {directories} {
    set events_str [rebuildDefinitionFile $directories]
    populateData $events_str
}

proc reframeItemsList {path listvar} {
    frame $path
    listbox "$path.item_list" \
        -yscrollcommand "$path.item_list_scroll set" \
        -listvariable $listvar

    scrollbar "$path.item_list_scroll" -command "$path.item_list yview"
    
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    grid "$path.item_list" \
        -in "$path" \
        -row 0 \
        -column 0 -sticky nsew
    grid "$path.item_list_scroll" -row 0 \
        -in $path \
        -column 1 -sticky ns
}

frame .searchbox_frame
frame .status_frame -background green

# search box
ttk::label .searchbox_frame.filter_label -text "Filter:"
ttk::entry .searchbox_frame.filter_entry -width 30 -textvariable name_filter
ttk::button .searchbox_frame.filter_button -text "Find" -command filterData
ttk::button .searchbox_frame.rebuild_button -text "Rebuild" -command rebuildIndex

ttk::notebook .reframe_tabs -padding {0 0 0 0}

# status bar
ttk::label .status_frame.status_label -textvariable index_build_status

proc openEditor {line_num file_name} {
    puts "emacsclient -n +[lindex $data 3] [lindex $data 2]"
    exec /Applications/Emacs.app/Contents/MacOS/bin/emacsclient -n +$line_num $file_name
}

proc selectionMade {w} {
    global event_data event_lookup_indices
    global reframe_data reframe_lookup_indices reframe_data_labels

    set reframe_type [selectedReframeType]
    foreach index [$w curselection] {
        set indices [dict get $reframe_lookup_indices $reframe_type]
        set data [lindex $reframe_data [lindex $indices $index]]
        # puts "Index --> $index, lookup index --> [lindex $indices $index], Text --> [$w get $index]"
        # puts "data: [lindex $reframe_data [lindex $indices $index]]"
        openEditor [lindex $data 3] [lindex $data 2]
    }
}

bind .searchbox_frame.filter_entry <KeyPress-Return> filterData

set search_box_row_number 0
set event_list_row_number 1
set status_frame_row      2

grid .searchbox_frame -row $search_box_row_number -columnspan 2 -sticky ew
grid .searchbox_frame.filter_label -row 0 -column 0 -in .searchbox_frame 
grid .searchbox_frame.filter_entry -row 0 -column 1 -in .searchbox_frame -sticky ew
grid .searchbox_frame.filter_button -row 0 -column 2 -in .searchbox_frame
grid .searchbox_frame.rebuild_button -row 0 -column 3 -in .searchbox_frame
grid columnconfigure .searchbox_frame 1 -weight 1

grid .reframe_tabs \
    -row $event_list_row_number \
    -column 0 -sticky nsew

grid rowconfigure .reframe_tabs 0 -weight 1
grid columnconfigure .reframe_tabs 0 -weight 1

grid rowconfigure . $event_list_row_number -weight 1
grid columnconfigure . 0 -weight 1

grid .status_frame -row $status_frame_row -columnspan 2 -sticky ew
grid .status_frame.status_label -row 0 -column 0 -in .status_frame -sticky e

foreach kv { {"Event" "events"} {"Sub" "subs"} {"FX" "effects"} {"CoFX" "coeffects"} } {
    set reframe_type [lindex $kv 0]
    set tab_name [lindex $kv 1]
    reframeItemsList ".reframe_tabs.$tab_name" "::data_$reframe_type"
    .reframe_tabs add ".reframe_tabs.$tab_name" -text $reframe_type
}

foreach tab_widget {events subs effects coeffects} {
    bind ".reframe_tabs.$tab_widget.item_list" <<ListboxSelect>> {selectionMade %W}
}

proc rebuildIndex {} {
    global source_paths
    initializeDeftool $source_paths
}

if { $argc > 0 } {
    global source_paths
    set source_paths ""
    for {set i 0} {$i < $argc} {incr i} {
        global source_paths
        set current [lindex $argv $i]
        set source_paths "$source_paths -r=$current "
    }
    rebuildIndex
} else {
    puts "missing argument: You must provide the comma separated paths to source roots"
    exit 1
}
