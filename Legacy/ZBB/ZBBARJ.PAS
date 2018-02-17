{
*****************************************************************************
*                                                                           *
*              ARJ Unit Copyright Predrag Knezevic (C) 1992                 *
*                             SEZAM:pedjak                                  *
*                         -This is Public Domain-                           *
*****************************************************************************
}
{$V-,D-,L-}
unit arj;
interface
const

     {Host OS}

     MSDOS    = 0;
     PRIMOS   = 1;
     UNIX     = 2;
     AMIGA    = 3;
     MAC_OS   = 4;
     OS_2     = 5;
     APPLE_GS = 6;
     ATARI_ST = 7;
     NEXT     = 8;
     VAX_VMS  = 9;

     {flags}

     Password =  1;  {indicates passworded file}
     Volume   =  4;  {indicates continued file to next volume(file is split)}
     ExtFile  =  8;  {indicates file starting position(for split files)}
     PathSym  = 16;  {indicates UNIXlike path "\" changed to "/"}
     Backup   = 32;  {indicates file marked as backup}

     {file type}

     Binary       = 0;
     Text_7bit    = 1;
     Directory    = 3;
     Volume_label = 4;

     {compression method}

     Stored             = 0;  {no compression}
     Best_compressed    = 1;  {best compression}
     Fast_compressed    = 2;  {less compression,fast}
     Faster_compressed  = 3;  {less compression,faster}
     Fastest_compressed = 4;  {less compression,fastest}

     {errors}

     FileNOTexist   = 1; {file is not exist on disk}
     NOT_ARJFile    = 2; {file is not ARJ file}
     eofARJfile     = 4; {end of ARJ archive}


type
	c=array[1..65535] of char;
	file_comment=^c;

	arjinfo = record
			vers_made_by     :byte;
			vers_to_extract  :byte;
			host_os          :byte;
			flags            :byte;
			date_time        :longint;
			arjname          :string[150]; {name of archive}
			comment_length   :word; 
			arjcomment       :file_comment; {comment of archive}
		   end;

	arjfile = record
			vers_made_by     :byte;
			vers_to_extract  :byte;
			host_os          :byte;
			flags            :byte;
			comp_method      :byte;
			file_type        :byte;
			date_time        :longint;
			comp_size        :longint;
			uncomp_size      :longint;
			crc              :longint;
			file_attributes  :word;    {external file attributes}
			ext_position     :longint;
                                         {starting position(for split files)}
			name             :string[150];
                        comment_length   :word;
			comment          :file_comment;
		  end;

procedure OpenARJ(fname:string;var info:arjinfo);
procedure CloseARJ;
procedure GetFirstARJfile(var farj:arjfile);
procedure GetNextARJfile(var farj:arjfile);
function CheckARJ(fname:string):boolean;
function eofARJ:boolean;
function ARJerror:byte;

implementation
type
	headerrec = record
			  header_id                           :word;
			  basic_header_size                   :word;
			  first_hdr_size                      :byte;
			  archiver_version_number             :byte;
			  minimum_archiver_version_to_extract :byte;
			  host_os                             :byte;
			  arj_flags                           :byte;
			  reserved1                           :byte;
			  file_type                           :byte;
			  reserved2                           :byte;
			  date_time_created                   :longint;
			  reserved3                           :longint;
			  reserved4                           :longint;
			  reserved5                           :longint;
			  filespec_position_in_filename       :word;
			  not_used1                           :word;
			  not_used2                           :word;
		    end;

	basicrec = record
			header_id                             :word;
			basic_header_size                     :word;
                   end;
        filerec = record
			first_hdr_size                        :byte;
			archiver_version_number               :byte;
			minimum_archiver_version_to_extract   :byte;
			host_os                               :byte;
			arj_flags                             :byte;
			method                                :byte;
			file_type                             :byte;
			reserved1                             :byte;
			date_time_modified                    :longint;
			compressed_size                       :longint;
			original_size                         :longint;
			original_crc                          :longint;
			filespec_position_in_filename         :word;
			file_access_mode                      :word;
			host_data                             :word;
		  end;

const
        error             :byte=0;
var
	first_file_offset :longint;
	next_file_offset  :longint;
	curent_file       :word;
        f                 :file;

procedure convertslash(var s:string);
begin
     while pos('/',s)<>0 do s[pos('/',s)]:='\';
end;
{end convertslash}

function CheckARJ;
var
   dat:file;
   signature:word;
begin
     if pos('.',fname)<>0 then assign(dat,fname)
     else assign(dat,fname+'.arj');
{$I-}
     reset(dat,2);
     if ioresult<>0 then
        begin
             error:=error or 1;
	     checkarj:=false;
             exit;
        end;
{$I+}
     blockread(dat,signature,1);
     close(dat);
     checkarj:=signature=$EA60;
     error:=0;
end;
{end CheckARJ}

procedure OpenARJ;
var
	ext_header,i:word;
	c:char;
	header,offset,ext_head_crc:longint;
	fileinfo:headerrec;
begin
     if not(CheckARJ(fname)) then
        begin
             error:=error or 2;
             exit;
        end;
     if pos('.',fname)<>0 then assign(f,fname)
     else assign(f,fname+'.arj');
     reset(f,1);
     blockread(f,fileinfo,sizeof(headerrec));
     with fileinfo do
	begin
		move(archiver_version_number,info.vers_made_by,4);
		info.date_time:=date_time_created;
	end;
     i:=0;
     blockread(f,info.arjname[i+1],1);
     while info.arjname[i+1]<>#0 do
	begin
		inc(i);
		blockread(f,info.arjname[i+1],1);
	end;
     info.arjname[0]:=chr(i);
     if (pos('/',info.arjname)<>0) then convertslash(info.arjname);
     offset:=filepos(f);
     i:=0;
     blockread(f,c,1);
     while c<>#0 do
	begin
		inc(i);
		blockread(f,c,1);
	end;
     info.comment_length:=i;
     if i>0 then
	begin
		getmem(info.arjcomment,i);
		seek(f,offset);
		blockread(f,info.arjcomment^,i);
		seek(f,filepos(f)+1);
	end;
     blockread(f,header,4);
     blockread(f,ext_header,2);
     if ext_header>0 then blockread(f,ext_head_crc,4);
     first_file_offset:=filepos(f);
     next_file_offset:=filepos(f);
     error:=0;
end;
{end OpenARJ}

procedure ReadARJ(offset_file:longint;var farj:arjfile);
var
   a:filerec;
   b:basicrec;
   i,ext_header:word;
   c:char;
   offset,header,ext_head_crc:longint;
begin
     seek(f,offset_file);
     blockread(f,b,sizeof(b));
     with b do
          begin
               if header_id<>$EA60 then
                                       begin
                                            error:=error or 2;
                                            exit;
                                       end;
          end;
     blockread(f,a,sizeof(a));
     with a do
          begin
               move(archiver_version_number,farj.vers_made_by,6);
               move(date_time_modified,farj.date_time,16);
               farj.file_attributes:=file_access_mode;
               if arj_flags and 8=8 then blockread(f,farj.ext_position,4);
               i:=0;
               blockread(f,farj.name[i+1],1);
               while farj.name[i+1]<>#0 do
	             begin
                          inc(i);
                          blockread(f,farj.name[i+1],1);
	             end;
               farj.name[0]:=chr(i);
               if (pos('/',farj.name)<>0) then convertslash(farj.name);
               offset:=filepos(f);
               i:=0;
               blockread(f,c,1);
               while c<>#0 do
	             begin
		          inc(i);
		          blockread(f,c,1);
                     end;
               farj.comment_length:=i;
               if i>0 then
	                  begin
		               getmem(farj.comment,i);
		               seek(f,offset);
		               blockread(f,farj.comment^,i);
		               seek(f,filepos(f)+1);
                          end;
               blockread(f,header,4);
               blockread(f,ext_header,2);
               if ext_header>0 then blockread(f,ext_head_crc,4);
               next_file_offset:=filepos(f)+a.compressed_size;
               error:=0;
          end;
end;
{end readARJ}

function eofARJ;
var
   a:basicrec;
begin
     seek(f,next_file_offset);
     blockread(f,a,sizeof(a));
     seek(f,next_file_offset);
     eofARJ:=a.basic_header_size=0;
end;
{end eofARJ}

procedure GetFirstARJfile;
begin
     readARJ(first_file_offset,farj);
end;
{end GetFirstARJfile}

procedure GetNextARJfile;
begin
     if eofARJ then
                   begin
                        error:=error or 4;
                        exit;
                   end;
     readARJ(next_file_offset,farj);
end;
{end GetNextARJfile}

function ARJerror;
begin
     ARJerror:=error;
     error:=0;
end;
{end ARJerror}

procedure CloseARJ;
begin
     close(f);
end;
{end CloseARJ}

end.
{end unit ARJ}
