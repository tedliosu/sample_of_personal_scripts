#!/bin/sh

# Temporary workaround for lack of file birth time field in a "stat" command output
#   until Ubuntu 22.04.02 LTS releases; the following function accepts a list of one
#   or more file names as the argument(s) on the command line, and then for each file
#   name prints to stdout the creation time of the associated file. The function is
#   able to do that for any REGULAR file or directory stored in an ext2, ext3, ext4,
#   ntfs, or exfat file system, as long as a valid relative or absolute filepath is
#   provided for each file as each argument to this function.
#
# I wrote the following code as one big function so that the function can be inserted
#   into any ".bashrc" or ".kshrc" file under a user's "~" directory. That way, the
#   user can have access to the following function from any directory the user wishes
#   to set as the working directory inside a bash terminal.
stat_crtime () {

   # Field separator to switch to when parsing file names with spaces
   #     in them from the command line.
   local FILES_PARSING_IFS="$(echo -ne "\n")"
   local sudo_cmd="sudo --set-home"
   # A space-delimited list of command-line programs this function uses
   #     to determine the creation time of each file parsed from the command
   #     line.
   local required_execs="debugfs ntfsinfo dumpexfat losetup flock python3"
   # A space-delimited list of all the different file systems that a file
   #     can reside on as parsed from the command line. This function does
   #     NOT support determining the file creation time of files stored
   #     on file systems OTHER THAN the ones in the following list.
   local supported_fs="ext2 ext3 ext4 ntfs exfat"
   # Flag constant indicating that the filesystem which the file
   #     parsed from the command line is on is a filesystem that
   #     this function cannot report file creation times for.
   local unsupported_fs_keyword="unsupported"
   # The following three variables store constants associated
   #     with the exFAT file system, such as the value of the
   #     character marking the beginning of a file entry in the
   #     file allocation table or the size of an file entry header
   #     in bytes in the exFAT file system.
   local exfat_file_entry_marker="85"
   local exfat_filename_marker="c1"
   local exfat_entry_header_size="64"
   # Convert space-delimited list of all the different supported
   #     file systems into a regular expression which can be used
   #     to parse file-system data for determining whether the
   #     file system is supported by this function or not.
   supported_fs="$(echo "$supported_fs" | tr -s " ")"
   local supported_fs_regex="$(echo "$supported_fs" | \
                                sed --regexp-extended "s/(^ )|( $)//g" | \
                                                                 tr " " "|")"
   # Exit status codes used by this function.
   local general_error_code="$("$(which false)" || echo "$?")"
   local success_code="$("$(which true)" && echo "$?")"
   local command_not_found_code="$(command-not-found >/dev/null 2>&1 || \
                                                                echo "$?")"
   # Embedded python script used to generate and maintain an
   #     dictionary caching each filesystem and each
   #     filesystem's mount point for each file parsed from
   #     the command line. The array maps each filesystem
   #     mount point to a filesystem type after obtaining the
   #     filesystem info from "blkid" once so that this function
   #     doesn't have to repeatedly call "blkid" on the mount
   #     point of each file system for each file parsed from
   #     the command line.  I didn't use Bash's built-in
   #     associative arrays because I wanted this function
   #     to be more portable across different shell languages.
   local python3_query_xor_update_script
   local file
	read python3_query_xor_update_script <<- END
		import sys\
		\\\nimport json\
		\\\nARRAY_CONTENTS_INDEX = 1\
		\\\nMOUNT_PT_INDEX = 2\
		\\\nFILESYS_TYPE_INDEX = 3\
		\\\narray = json.loads(sys.argv[ARRAY_CONTENTS_INDEX])\
		\\\nmount_pt = sys.argv[MOUNT_PT_INDEX]\
		\\\nfilesys_type = ""\
		\\\nif len(sys.argv) > FILESYS_TYPE_INDEX:\
		\\\n	filesys_type = sys.argv[FILESYS_TYPE_INDEX]\
		\\\nif len(filesys_type) <= 0:\
		\\\n	if mount_pt in array:\
		\\\n		print(array[mount_pt])\
		\\\nelse:\
		\\\n	array[mount_pt] = filesys_type\
		\\\n	print(json.dumps(array))
	END
   python3_query_xor_update_script="$(echo -e "$python3_query_xor_update_script")"
   echo ""

   # Check to make sure that this function has all of the command line programs
   #     it needs to get the file creation date of each file parsed from the
   #     command line.
   if [ "$(which $required_execs | \
                               wc -l)" -lt "$(echo "$required_execs" | \
                                              egrep --only-matching "[^ ]+" | \
                                                                          wc -l)" ]; then

      echo "Please make sure the package(s) which provides the following" >&2
      echo "   program(s) for your distro are installed, and that" >&2
      echo -e "   the programs are in your environment PATH - $required_execs\n" >&2
      # If a program this function needs is missing, let user know which programs
      #     this function needs and exit function with "command not found" exit
      #     status.
      return "$command_not_found_code"
 
   # Otherwise, if the user has not provided any command-line arguments to this
   #     function, then print out a usage statement, the file system types that
   #     this function supports for getting the file creation time of each file,
   #     and the explanation for how it is not possible for this function to
   #     support getting the file creation time of files stored on a FAT16/FAT32
   #     file system.
   elif [ -z "$(echo "$@")" ]; then
 
      echo "Usage $0 [REGULAR FILE OR DIRECTORY]..."
      echo "***Supported filesystem types: $supported_fs"
      echo "***Blame the Linux kernel for overwriting the equivalent of the"
      echo "   crtime field for vfat (a.k.a. fat16/fat32) filesystems:"
      echo -e "   https://www.anmolsarma.in/post/linux-file-creation-time/\n"
   
   # If this function has recieved at least one command line argument, then
   #     start querying the file creation time of each file provided as a
   #     command line argument.
   else
   
      # Inform user that password input may be necessary for this function
      #     to perform filesystem-related actions requiring superuser
      #     privileges.
      echo "Some of the subsequent operations performed by $0 may" >&2
      echo "   require elevated privileges; please enter your password" >&2
      echo "   for 'sudo' if prompted." >&2
      # The following two variables store executable locations
      #     for system-wide installations of "flock" and "losetup"
      #     for getting file creation times of files stored
      #     on exFAT and NTFS file systems by mounting each
      #     of those filesystems on a loop device.
      local flock_exec="$(whereis -b flock | cut -d" " -f2)"
      local losetup_exec="$(whereis -b losetup | cut -d" " -f2)"
      # Number of nibbles in the header of a file entry in the
      #     file allocation table in the exFAT file system.
      local exf_entry_header_nibbles="$((($exfat_entry_header_size - 1) * 2))"
      # The caching dictionary mapping each file system mount point
      #     to a file system type, represented as a JSON array.
      local mount_pt_fs_type_array="{}"
      # List of all loop devices in use by this function,
      #     where each loop device is attached to a read-only
      #     copy of the filesystem that the file resides on,
      #     where the file is being parsed by this function
      #     for its creation time.
      local all_fs_mirrors=""
      # Switch field separators used by the shell so that
      #     file names with spaces in them may be properly
      #     parsed by this function.
      local PREVIOUS_IFS="$IFS" && IFS="$FILES_PARSING_IFS"

      # For each file provided as a command line argument, get the
      #     file creation time if the underlying file system is 
      #     supported by this function, and print the file creation
      #     time to stdout.
      for file in $@; do

         # Revert field separators used by the shell to the original ones
         IFS="$PREVIOUS_IFS"
         # If the file parsed from the command line isn't
         #     a regular file or regular directory that
         #     exists, then inform user that the file
         #     can't be processed. Also provide a hint
         #     to the user on how to properly pass
         #     symlinks as arguments to this function
         #     in case that is the reason why this
         #     function didn't properly detect the
         #     file's existence.
         if [ ! -f "$file" ] && [ ! -d "$file" ]; then

            echo -n "$0: cannot $0 \"$file\": " >&2
            echo "No such regular file or directory" >&2
            echo "***Hint: replace \"$file\" with " >&2
            echo "   \"\$(realpath -e \"$file\")\" if it is" >&2
            echo "   a working symbolic link to a regular file." >&2

         else
         
            # Next 5-7 lines of code obtains file system information
            #     associated with each file parsed from the command
            #     line to determine how this function should go about
            #     obtaining the file creation time for each file.
            #     The code also attempts to fetch the file system
            #     type from the caching dictionary stored in
            #     "mount_pt_fs_type_array" using the mount point
            #     of the file system on which the file resides
            #     as a key. The code then initializes the variable
            #     storing the file creation time.
            local filesystem_info="$(df "$file" | tail -n1)"
            local filesys_loc="$(echo "$filesystem_info" | cut -d" " -f1)"
            local filesystem_mount_pt="$(echo "$filesystem_info" | \
                                                       tr -s " " | cut -d" " -f6)"
            local filesystem_type="$(python3 -c "$python3_query_xor_update_script" \
                                      "$mount_pt_fs_type_array" "$filesystem_mount_pt")"
            local file_crtime=""
            # If caching dictionary stored in "mount_pt_fs_type_array"
            #     does not contain ANY filesystem type info on the
            #     filesystem on which the file being parsed resides,
            #     then use blkid to obtain the file system type info. 
            #     Then store the file system mount point as the key and
            #     filesystem type as the value within the caching
            #     dictionary stored in "mount_pt_fs_type_array". If
            #     the file system type is not supported by this
            #     function, then the value of "unsupported_fs_keyword"
            #     will be stored as the value of the file-system-
            #     mountpoint-file-system-type pair within the
            #     dictionary.
            if [ -z "$filesystem_type" ]; then
               filesystem_type="$(blkid | tr -s "=\"" " " | \
                                      grep "$filesys_loc" | \
                                      egrep --only-matching "$supported_fs_regex")"
               test -z "$filesystem_type" && filesystem_type="$unsupported_fs_keyword"
               mount_pt_fs_type_array="$(python3 -c "$python3_query_xor_update_script" \
                                          "$mount_pt_fs_type_array" "$filesystem_mount_pt" \
                                                                          "$filesystem_type")"
            fi
            
            # Let user know if the file creation time cannot be retrieved
            #     because the underlying file system isn't supported
            #     by this function.
            if [ "$filesystem_type" = "$unsupported_fs_keyword" ]; then
            
               echo -n "$0: cannot $0 \"$file\": " >&2
               echo "Unsupported filesystem" >&2
            
            # If the underlying file system on which the file being
            #     parsed resides is either ext2, ext3, or ext4,
            #     then use the "debugfs" utility program to obtain
            #     the file creation time and print out the time to
            #     the user.  The "stat" program is used to obtain
            #     the file inode number used by "debugfs" to obtain
            #     the file creation time, and the "date" program
            #     is used to format the time printed out to the
            #     user, where the formatting mimics the formatting
            #     of access, modification, and change times printed
            #     out for any file by the "stat" program.
            elif [ "${filesystem_type%%?}" = "ext" ]; then
               local file_inode="$(stat --format="%i" "$file")" && \
                  file_crtime="$(debugfs -R "stat <$file_inode>" \
                                            "$filesys_loc" 2>&1 | \
                                      grep "crtime" | cut -d" " -f4-)" && \
                  file_crtime="$(date --date "$file_crtime" +"%Y-%m-%d %T.%N %z")"
               echo -e " File: $file\nBirth: ${file_crtime:--}"
            
            # If the filesytem on which the file parsed from the command line resides
            #     is either NTFS or exFAT, then attach the filesystem as a loop device
            #     so that either "ntfsinfo" (for NTFS file systems) or "dumpexfat" and
            #     "dd" (for exFAT file systems) can be used to either directly obtain
            #     the file creation time or parse the underlying raw bytes from the
            #     filesystem to parse out the file creation time WITHOUT having to
            #     completely unmount the underlying filesystem.
            elif [ "$filesystem_type" = "ntfs" ] || [ "$filesystem_type" = "exfat" ]; then
               
               # Attempt to fetch the loop device associated with
               #     the root of the filesystem on which the file
               #     resides by querying the loop device associated
               #     with the root of the filesystem.
               local fs_mirror="$($losetup_exec --associated \
                                                 "$filesys_loc" | \
                                                      cut -d":" -f1)"
               # If the root of the filesytem (on which the file resides) is
               #     not associated with any loop device, then repeatedly
               #     attempt to acquire a lock on the first available loop
               #     device found and then attach the root of the filesystem
               #     to that loop device (as a "read-only" filesystem) after
               #     the lock is successfully acquired.
               if [ -z "$fs_mirror" ]; then
                  local flock_exit_code="$general_error_code"
                  while [ "$flock_exit_code" -ne "$success_code" ]; do
                     $sudo_cmd "$(which true)" && \
                       fs_mirror="$($sudo_cmd $losetup_exec --nooverlap --find)" && \
                       $sudo_cmd $flock_exec --nonblock "$fs_mirror" \
                          --command "$sudo_cmd $losetup_exec --read-only $fs_mirror $filesys_loc" && \
                       flock_exit_code="$?"
                  done
               fi
               # Add the loop device stored in "fs_mirror" (which a read-only copy
               #     of an NTFS or exFAT filesystem is attached to) to the list of
               #     loop devices in use by this function if the loop device isn't
               #     already in the list stored in "all_fs_mirrors", and in case
               #     if the interrupt signal gets sent to this function while this
               #     function is running, set up a signal handler to detach all
               #     loop devices in use by this function when this function
               #     receives the interrupt signal (say from a user pressing ctrl+c).
               if [ -z "$(echo "$all_fs_mirrors" | grep --only-matching "$fs_mirror")" ]; then
                  all_fs_mirrors="$all_fs_mirrors $fs_mirror"
                  echo "---Added loop device $fs_mirror---" >&2 # Inform user that we've used up a loop device.
                  local sig_int_response="trap \"\" INT && echo \"---Recieved SIGINT---\" >&2 && sleep 3 " && \
                  sig_int_response="$sig_int_response&& $sudo_cmd $losetup_exec --detach $all_fs_mirrors " && \
                  sig_int_response="$sig_int_response&& echo \"---Detached loop devices$all_fs_mirrors---\" >&2 " && \
                  sig_int_response="$sig_int_response&& trap - INT"
                  trap "$sig_int_response" INT
               fi
               # Get absolute file path of current file parsed from command line
               #     and then remove (from the absolute file path) the part of
               #     the file path corresponding to the mountpoint of the
               #     filesystem on which the file resides and store the
               #     result under "file_relative_path".
               local file_realpath="$(realpath --canonicalize-existing "$file")"
               local file_relative_path="${file_realpath#$filesystem_mount_pt}"
               
               # If the underlying file system on which the current file
               #     resides is of NTFS type, then use the "ntfsinfo"
               #     program to obtain all information about the file
               #     first. Then pipe the output from "ntfsinfo" to
               #     "grep" to filter out the file creation time, and
               #     then format the time using the "date" program to
               #     display to the user in a format similar to how
               #     "stat" displays a file's access/modification/change
               #     times to the user.
               if [ "$filesystem_type" = "ntfs" ]; then

                  local ntfsinfo_result="$(ntfsinfo --file "$file_relative_path" "$fs_mirror")" && \
                     file_crtime="$(echo "$ntfsinfo_result" | \
                                       grep --max-count=1 "File Creation Time" | \
                                                   tr -s "\t" " " | cut -d" " -f5-)" && \
                     file_crtime="$(date --date "$file_crtime" +"%Y-%m-%d %T.%N %z")"
                  echo -e " File: $file\nBirth: ${file_crtime:--}"

               # Otherwise, get file creation date of file on exFAT file system.
               else

                  # Get the directory in which the file resides relative to
                  #     the mount point of the exFAT filesystem.
                  local file_relative_dir="$(dirname "$file_relative_path")"
                  # If the relative location of the file (relative to the
                  #     mount point of the filesystem) parsed from the
                  #     command line is somehow exactly the symbol
                  #     representing the root of a filesystem for *nix
                  #     systems, then tell user that the file creation
                  #     time cannot be retrieved because the exFAT file
                  #     system does not store the file creation time
                  #     for the file represented by that symbol.
                  if [ "$file_relative_path" = "/" ]; then
                     echo "$0: cannot $0 \"$file\": exfat file system" >&2
                     echo "   root does not store creation date." >&2
                  else
                     # The next 2-6 lines of code basically encode the relative
                     #     location of the file as a hexadecimal sequence where
                     #     within that sequence, each byte of the file location
                     #     is padded on either side by 2 zeros. That encoded
                     #     relative location is then embedded into a regex which
                     #     is then used to "capture" the contents of the file's
                     #     entry header from the file allocation table so that
                     #     the file creation date may be parsed out from the header.
                     local filename_encoded="$(basename "$file_relative_path" | \
                                                    tr -d "\n" | \
                                                    xxd -plain -groupsize 0 | tr -d "\n" | \
                                                    sed "s/[[:alnum:]]\{,30\}/$exfat_filename_marker&/g" | \
                                                                              sed "s/[[:alnum:]]\{2\}/&00/g")"
                     local file_info_regex="$exfat_file_entry_marker[[:alnum:]]{$exf_entry_header_nibbles}(?=$filename_encoded)"
                     # Get all of the starting locations and sizes of each file
                     #     fragment for the file currently being processed from
                     #     the underlying exFAT filesystem.
                     local dir_sizes_n_locations="$(dumpexfat -f "$file_relative_dir" \
                                                                      "$fs_mirror" 2>&1 | tail -n+2)"
                     # Next twenty-one lines of code iterates through each file
                     #    fragment using "dd" by directly reading the filesystem's
                     #    underlying raw bytes. Using information reported by
                     #    "dumpexfat" about each file fragment of the file
                     #    being processed, we go to the location of each file
                     #    fragement and read out that entire fragment using "dd",
                     #    and each fragment read is then parsed using the regex
                     #    we created above (containing the relative file
                     #    location) to attempt to extract the file
                     #    entry header from all those different file fragments.
                     #    As soon as we've successfully extracted the file
                     #    entry header (which contains the file creation time
                     #    info we need), i.e. "exfat_file_info" is no longer
                     #    an empty string and contains a regex match from
                     #    parsing out the file entry header, we stop parsing
                     #    each file fragment and exit the while loop as written
                     #    below.
                     local exfat_file_info=""
                     # Date extraction code references: https://github.com/relan/exfat;
                     #   https://blog.1234n6.com/2018/07/exfat-timestamps-exfat-primer-and-my.html
                     exfat_file_info="$(echo "$dir_sizes_n_locations" | \
                                          while read frag_info; do \
                                            local dir_frag_byte_offset="$(echo "$frag_info" | \
                                                                                  cut -d" " -f1)"; \
                                            local dir_frag_size="$(echo "$frag_info" | \
                                                                           cut -d" " -f2)"; \
                                            exfat_file_info="$(dd status=none \
                                                                  iflag=skip_bytes,count_bytes \
                                                                  skip="$dir_frag_byte_offset" \
                                                                  count="$dir_frag_size" \
                                                                              if="$fs_mirror" | \
                                                                xxd -plain -groupsize 0 | tr -d "\n" | \
                                                                grep --only-matching --perl-regexp \
                                                                                       "$file_info_regex")"; \
                                            if [ -n "$exfat_file_info" ]; then \
                                              echo "$exfat_file_info"; \
                                              break; \
                                            fi; \
                                          done)"
                     # Next fourty-five lines of code is the painstaking process of
                     #     decoding the bitfields storing the file creation date
                     #     within the file entry header parsed out from the underlying
                     #     filesystem, and then printing out the decoded result to
                     #     the user.  Quite a bit of regex, bitwise operations,
                     #     basic math calculations, and general string manipulations
                     #     are used to convert the bitfields into a formatted file
                     #     creation time to be echoed out to the user.
                     # "cr" in the following variable names stands for "creation".
                     local cr_o_clock="$(echo "$exfat_file_info" | tail -c+17 | head -c4)"
                     local cr_date="$(echo "$exfat_file_info" | tail -c+21 | head -c4)"
                     local cr_centisec="$(echo "$exfat_file_info" | tail -c+41 | head -c2)"
                     local cr_timezone="$(echo "$exfat_file_info" | tail -c+45 | head -c2)"
                     cr_o_clock="$(echo "$cr_o_clock" | sed "s/[[:alnum:]]\{2\}/&\n/g" | \
                                                                           tac | tr -d "\n")"
                     cr_date="$(echo "$cr_date" | sed "s/[[:alnum:]]\{2\}/&\n/g" | \
                                                                     tac | tr -d "\n")"
                     local cr_day_of_mon="$((0x$cr_date & 0x1f))" && \
                        test "${#cr_day_of_mon}" -eq "1" && cr_day_of_mon="0$cr_day_of_mon"
                     local cr_month="$((0x$cr_date >> 5 & 0xf))" && \
                        test "${#cr_month}" -eq "1" && cr_month="0$cr_month"
                     local cr_year="$(((0x$cr_date >> 9) + 1980))"
                     local cr_secs="$(((0x$cr_o_clock & 0x1f) << 1))"
                     local cr_min="$((0x$cr_o_clock >> 5 & 0x3f))" && \
                        test "${#cr_min}" -eq "1" && cr_min="0$cr_min"
                     local cr_hour="$((0x$cr_o_clock >> 11))" && \
                        test "${#cr_hour}" -eq "1" && cr_hour="0$cr_hour"
                     cr_secs="$(echo "scale=2; $((0x$cr_centisec)) / 100 + $cr_secs" | bc)" && \
                        test "${#cr_secs}" -eq "4" && cr_secs="0$cr_secs"
                     test -n "$cr_year" && test -n "$cr_month" && test -n "$cr_day_of_mon" && \
                        test -n "$cr_hour" && test -n "$cr_min" && test -n "$cr_secs" && \
                        file_crtime="${cr_year}-${cr_month}-${cr_day_of_mon} " && \
                        file_crtime="${file_crtime}$cr_hour:$cr_min:$cr_secs"
                     # cr_timezone="ec"
                     # If the timezone offset stored in the bitfields in
                     #     the file entry header for the file creation time
                     #     is zero, then simply print out the decoded
                     #     file creation time to the user.
                     if [ "$((0x$cr_timezone & 0x80))" -eq "0" ]; then
                        test -n "$file_crtime" && \
                           file_crtime="${file_crtime}0000000 $(date +"%z")"
                        echo -e " File: $file\nBirth: ${file_crtime:--}"
                     # Otherwise, after decoding the timezone offset
                     #     as the number of seconds offset from UTC,
                     #     convert the raw file creation time into
                     #     unix epoch time and subtract the offset
                     #     from the epoch time, then convert the epoch
                     #     time into a human-readable time format
                     #     and display the resulting file creation
                     #     time to the user.
                     else
                        local calc_success=""
                        cr_timezone="$(((0x$cr_timezone & 0x7f) << 1))" && \
                             calc_success="$?" && \
                             test "$cr_timezone" -gt "127" && \
                             cr_timezone="$(($cr_timezone - 256))"
                        test -n "$calc_success" && \
                           cr_timezone="$(($cr_timezone * 15 * 60 / 2))"
                        unset calc_success
                        test -n "$file_crtime" && test -n "$cr_timezone" && \
                           local cr_unix_time="$(echo "$(date --utc --date \
                                                            "$file_crtime" \
                                                                    +"%s.%N") - $cr_timezone" | bc)" && \
                           file_crtime="$(date --date "@$cr_unix_time" +"%Y-%m-%d %T.%N %z")"
                        echo -e " File: $file\nBirth: ${file_crtime:--}"
                     fi
                  fi

               fi
            fi
         fi
         # Switch field separators to those used to parse
         #     out file names from the command line.
         IFS="$FILES_PARSING_IFS"
      done
      # Revert to original field separators used by the shell.
      if [ "$IFS" = "$FILES_PARSING_IFS" ]; then
         IFS="$PREVIOUS_IFS"
      fi
      # Since getting file creation dates of files received as command line
      #     arguments is finished now, we may detach all file systems which
      #     were attached to loop devices (for obtaining file creation date
      #     information) and inform user of loop device detachments.
      if [ -n "$all_fs_mirrors" ]; then
         $sudo_cmd "$(which true)" && \
            $sudo_cmd $losetup_exec --detach $all_fs_mirrors && \
            echo "---Detached loop devices$all_fs_mirrors---" >&2 && trap - INT
      fi
      echo ""
   fi
}

stat_crtime "$@"

