{$V-}

{
*****************************************************************************
*                                                                           *
*                  Zip Unit  Copyright Predrag Knezevic (C) 1992            *
*                             SEZAM:pedjak                                  *
*                      -This is Public domain unit-                         *
*****************************************************************************
}

unit zip;

interface

const

     {host os}

     MSDos      = 0; {and OS/2 (FAT file system)}
     Amiga      = 1;
     VMS        = 2;
     Unix       = 3;
     VM_CMS     = 4;
     AtariST    = 5;
     OS_2       = 6; {OS/2 (HPFS file system)}
     Macintosh  = 7;
     Z_System   = 8;
     CP_M       = 9;

     {compression method}

     Stored     = 0; {The file is stored(no compression)}
     Shrinking  = 1; {The file is Shrunk}
     Expanding1 = 2; {The file is Reduced with compression faktor 1}
     Expanding2 = 3; {The file is Reduced with compression faktor 2}
     Expanding3 = 4; {The file is Reduced with compression faktor 3}
     Expanding4 = 5; {The file is Reduced with compression faktor 4}
     Imploding  = 6; {The file is Imploded}

     {errors}

     fileNOTexist  = 1; {file not exist on disk}
     NOTzipfile    = 2; {file is not ZIP file}
     eofARJfile    = 3; {end of ZIP file}

     {filetype}

     textfile   = 1; {ASCII or text file}
     binaryfile = 0; {binary data}

type
    c = array[1..65535] of char;
    e = array[1..65535] of byte;

    file_comment = ^c;
    extra_field  = ^e;
    zipfile = record
        name               :  string[150];  { Filename of compressed file }
        host_os            :  byte;         { Idicates host OS for file   }
        vers_made_by       :  word;
         { Idicates the software used to encode.
           Upper byte - major version
           lower      - minor version   }
        vers_to_extract    :  word;
        encrypted          :  boolean;
        sliding_dictionary :  byte;
            {If the compression method used was Imploding (6),then
            indicates an 8 Kb or 4 Kb sliding dictionary was used.}
        shanon_fano_tree   :  byte;
            {If the compression method uses was Imploding (6) then
             indicates 3 or 2 Shanon-Fano trees were used to encode
             sliding dictionary output}
        comp_method        :  word;
            {Compression method}
        date_time          :  longint;
            {date and time are encoded in standard MS-DOS format.Use
             standard procedure Dos.UnpackTime to convert packed date-time
             longint into an unpacked DateTime record}
        crc32              :  longint;
            {CRC of the file}
        comp_size          :  longint;
            {Compressed size of the file}
        uncomp_size        :  longint;
            {Uncompressed size of the size}
        extra_field_length :  word;
            {The length of extra field}
        comment_length     :  word;
            {The length of comment field}
        disk_number_start  :  word;
            {The number of the disk on wich this file begins}
        file_type          :  byte;
            {This field indicates,if set on 1, that the file is apperently
             text file.If is 0,the file contains binary data}
        file_attributes    :  longint;
            {The mapping of the external attributes is host-system depndent
             (see field vers_made_by).For MS-DOS,the low order byte is the
             MS-DOS attribute byte}
        comment            :  file_comment;
            {The file comment}
        extra              :  extra_field;
            {extra field}
    end;

    zipinfo = record
       number_of_disk             :word;
            {The number of this disk, which contains central directory}
       start_cent_dir             :word;
            {The number of the disk on which the central directory start}
       total_entries              :word;
            {The total number of files in the zipfile}
       zipfile_comment_length     :word;
            {The length of comment for this zipfile}
       zipfile_comment            :file_comment;
            {The comment for this zipfile}
    end;

procedure OpenZIP(fname:string;var info:zipinfo);
procedure CloseZIP;
procedure GetFirstZIPfile(var fzip:zipfile);
procedure GetNextZIPfile(var fzip:zipfile);
function  CheckZIP(fname:string):boolean;
function  eofZIP:boolean;
function  ZIPerror:byte;

implementation
type
    central_dir = record
                    _signature:longint;
                    _version_made_by:word;
                    _version_needed_to_extract:word;
                    _general_purpose_bit_flag:word;
                    _compression_method:word;
                    _date_time:longint;
                    _crc_32:longint;
                    _compressed_size:longint;
                    _uncompressed_size:longint;
                    _filename_length:word;
                    _extra_field_length:word;
                    _file_comment_length:word;
                    _disk_number_start:word;
                    _internal_attributes:word;
                    _external_attributes:longint;
                    _offset_of_local_header:longint;
                  end;

    end_of_central_dir = record
      _number_of_disk:word;
      _number_of_disk_with_start_of_central_directory:word;
      _total_number_entries_on_this_disk:word;
      _total_number_entries_in_central_dir:word;
      _size_of_central_dir:longint;
      _offset_of_start_of_central_dir:longint;
      _zipfile_comment_length:word;
    end;

var
   first_file_offset:longint;
   next_file_offset:longint;
   total_files:word;
   curent_file:word;
   error:byte;
   f:file;

Procedure convertslash(var s:string);
begin
  while pos('/',s)<>0 do s[pos('/',s)]:='\';
end;
{end convertslash}

function CheckZIP;
var
  dat:file;
  signature:longint;
begin
     if pos('.',fname)<>0 then assign(dat,fname)
     else assign(dat,fname+'.zip');
{$I-}
     reset(dat,4);
     if ioresult<>0 then
        begin
             error:=1;
             checkzip:=false;
             exit;
        end;
{$I+}
     blockread(dat,signature,1);
     close(dat);
     checkzip:=signature=$04034B50;
     error:=0;
end;
{end CheckZIP}

procedure OpenZIP;
var
   i,header:longint;
   fileinfo:end_of_central_dir;
begin
     if not(CheckZIP(fname)) then
        begin
             inc(error,2);
             exit;
        end;
     if pos('.',fname)<>0 then assign(f,fname)
     else assign(f,fname+'.zip');
     reset(f,1);
     i:=filesize(f)-4;
     seek(f,i);
     blockread(f,header,4);
     while header<>$06054B50 do
           begin
                dec(i);
                seek(f,i);
                blockread(f,header,4);
           end;
     blockread(f,fileinfo,sizeof(fileinfo));
     move(fileinfo._number_of_disk,info.number_of_disk,4);
     info.total_entries:=fileinfo._total_number_entries_in_central_dir;
     total_files:=fileinfo._total_number_entries_in_central_dir;
     first_file_offset:=fileinfo._offset_of_start_of_central_dir;
     next_file_offset:=fileinfo._offset_of_start_of_central_dir;
     curent_file:=1;
     info.zipfile_comment_length:=fileinfo._zipfile_comment_length;
     with info do
          begin
               getmem(zipfile_comment,zipfile_comment_length);
               blockread(f,zipfile_comment^,zipfile_comment_length);
          end;
     error:=0;
end;
{end OpenZIP}

procedure readZIP(offset:longint;var fzip:zipfile);
var
   a:central_dir;
begin
     seek(f,offset);
     blockread(f,a,sizeof(a));
     with a do
          begin
               if _signature<>$02014B50 then
                                            begin
                                                 inc(error,2);
                                                 exit;
                                            end;
               fzip.host_os:=hi(_version_made_by);
               fzip.vers_made_by:=lo(_version_made_by) div 10;
               fzip.vers_made_by:=fzip.vers_made_by shl 8;
               fzip.vers_made_by:=fzip.vers_made_by+lo(_version_made_by) mod 10;
               fzip.vers_to_extract:=lo(_version_needed_to_extract) div 10;
               fzip.vers_to_extract:=fzip.vers_to_extract shl 8;
               fzip.vers_to_extract:=fzip.vers_to_extract+lo(_version_needed_to_extract) mod 10;
               fzip.encrypted:=_general_purpose_bit_flag and 1=1;
               if _compression_method=6 then
                  begin
                       if _general_purpose_bit_flag and 2=2 then fzip.sliding_dictionary:=8
                       else fzip.sliding_dictionary:=4;
                       if _general_purpose_bit_flag and 4=4 then fzip.shanon_fano_tree:=3
                       else fzip.shanon_fano_tree:=2;
                  end;
               move(_compression_method,fzip.comp_method,18);
               move(_extra_field_length,fzip.extra_field_length,6);
               fzip.file_type:=lo(_internal_attributes);
               fzip.file_attributes:=_external_attributes;
               fzip.name[0]:=chr(_filename_length);
               blockread(f,fzip.name[1],_filename_length);
               if pos('/',fzip.name)<>0 then convertslash(fzip.name);
               getmem(fzip.comment,_file_comment_length);
               getmem(fzip.extra,_extra_field_length);
               if _file_comment_length>0 then blockread(f,fzip.comment^,_file_comment_length);
               if _extra_field_length>0 then blockread(f,fzip.extra^,_extra_field_length);
               next_file_offset:=filepos(f);
               inc(curent_file);
               error:=0;
          end;
end;
{end readZIP}

function eofZIP;
begin
     eofZIP:=curent_file>total_files;

end;
{end eofZIP}

procedure GetFirstZIPfile;
begin
     curent_file:=1;
     readZIP(first_file_offset,fzip);
end;
{end GetFirstZIPfile}

procedure GetNextZIPfile;
begin
     if eofZIP then
        begin
             error:=3;
             exit;
        end;
     readZIP(next_file_offset,fzip);
end;

function ZIPerror;
begin
     ZIPerror:=error;
end;
{end ZIPerror}

procedure CloseZIP;
begin
     close(f);
end;
{end CloseZIP}

end.
{end unit ZIP}
