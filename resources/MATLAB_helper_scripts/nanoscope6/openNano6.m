function [images channel_info] = openNano(file_name)

% openNano version 6.0
% Last updated: 01-06-2006 by Macerano Blanco for correctly reading
% Nanoscope 6 files
% 
% [images Channel_Info ]=openNano(filename)
%
% Reads images from a Nanoscope 6 image files. The images are stored in
% "images" and can be displayed with imshow(images(:,:,channel_number). The
% relevant channel number can be found in the print output fromt this subroutine
% Basic channel information can be found in Channel_Info that for each
% channel contains, the name, trace/retrace, unit and x and y scan size
%
% Example:
% [images channel_info]=openNano('C:\Briefcase\Parchment\AFM\Dimension\CR41\CR41.000');
% The output of this command is:
%  Channel                                     Unit    
%   1. Height                   Trace          um
%   2. Deflection               Trace          V
%
% The following command images the trace height. The height is specified in
% microns:
% imshow(images(:,:,1),[]);
% This image can be stored as a gray scale image with
% imwrite(mat2gray(images(:,:,1)),'g:/traceheight.tif','tif');
 
% This function/script is authorized for use in government and academic
% research laboratories and non-profit institutions only. Though this
% function has been tested prior to its posting, it may contain mistakes or
% require improvements. In exchange for use of this free product, we 
% request that its use and any issues that may arise be reported to us. 
% Comments and suggestions are therefore welcome and should be sent to 
% 
% Jaco de Groot
% Bone & Mineral Centre, Dept of Medicine
% University College London
% 5 University Street
% The Rayne Building
% London    WC1E 6JJ
% Tel: 020-7679 6143
% Mob: 07745-948245  
% Fax: 020-7679 6219
% Email: jacodegroot@yahoo.se
% http://www.ucl.ac.uk/medicine/bmc/

searchstring(1).label='@2:Z scale:';
searchstring(2).label='Samps';
searchstring(3).label='Lines:';
searchstring(4).label='Data offset';
searchstring(5).label='Image Data:';
searchstring(6).label='Scan Size:';
%searchstring(7).label='@Sens. Zscan:';
%searchstring(7).label='@Sens. ZSensorSens:';
searchstring(7).label='@Sens. Zsens:';
searchstring(8).label='@Z magnify:';
searchstring(9).label='Line Direction:';

param=read_header_values(file_name,searchstring);
scaling       = param(1).values; %Scaling parameters
Z_Magnification= param(8).values; %Zmagnification
spl           = param(2).values; %Samples per line
linno         = param(3).values; %No of lines 
image_pos     = param(4).values; %Data position
Z_Sensitivity = param(7).values; %Data position
L = length(image_pos);

for im=1:2  % 20210310 Adapt to only take first 2 images, Trace + Retrace.
    channel_info(im).Trace=char((param(9).trace)*['Trace  ']+(1-param(9).trace)*['Retrace']);
    % ADDED 20210511: check if for some reason file is missing width/length
    % for each channel. If so, use first (and only) value in header 
    if length(param(6).values) == 1
        channel_info(im).Width = param(6).values;
        channel_info(im).Length = param(6).values;
    else
        channel_info(im).Width = param(6).values(2); %Data position
        channel_info(im).Length = param(6).values(3); %Data position
    end
    channel_info(im).Name=param(5).channel(im).name; %Name of channel 1
    channel_info(im).Zsensitivity=Z_Sensitivity;
    channel_info(im).scaling=param(1).values(im);
    channel_info(im).Z_Magnification=param(8).values(im);
    
    switch channel_info(im).Name
        case 'Height'
           channel_info(im).Unit='nm' ;
           finalscaling(im)=(scaling(im)*Z_Sensitivity)/(65535+1);
           channel_info(im).Finalscaling=finalscaling(im);
           
        case 'Deflection'
           channel_info(im).Unit='V';        
           %finalscaling(im)=scaling(im)/(65535+1);
           finalscaling(im)=(Z_Magnification(im)*scaling(im))/(65535+1);
        case 'Phase'    
            channel_info(im).Unit='Degree';
            %finalscaling(im)=scaling(im)/(65535+1);
            finalscaling(im)=(Z_Magnification(im)*scaling(im))/(65535+1);
        case 'Potential'    
            channel_info(im).Unit='V';
            channel_info(im).Finalscaling(im)=param(8).values(im)*param(1).values(im);
            finalscaling(im)=(Z_Magnification(im)*scaling(im))/(65535+1);
    end;         
end;    


fid = fopen(file_name,'r');

%disp(' ');disp('      Channel                                 Unit    ' ); 
for i = 1:2 % 20210310 Adapt to only take first 2 images, Trace + Retrace.
   
   fseek(fid,image_pos(i),-1); 
   A = fread(fid, [spl(i) linno],'int16');
   images(:,:,i) = rot90(finalscaling(i)*A);
   %images(:,:,i) = rot90(A);
%    emptystring=[];   
%    stringsize=25-size(channel_info(i).Name,2);
%    for n=1:stringsize emptystring=[emptystring ' ']; end
%    disp(['   ' num2str(i) '. ' channel_info(i).Name emptystring  channel_info(i).Trace '        '  channel_info(i).Unit]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%function [header ] = read_header(file_name);
function [parameters] = read_header_values(file_name,searchstring)
    
    % Define End of file identifier
    % Opend the file given in argument and reference as
    % fid.  Also if there was an error output error
    % number and error message to screen
    fid = fopen(file_name,'r');
    [message,errnum] = ferror(fid);
    if(errnum)
        fprintf(1,'I/O Error %d \t %s',[errnum,message]);
        %   break
    end
    header_end=0; eof = 0; counter = 1; byte_location = 0;
    nstrings=size(searchstring,2); 
    for ij=1:nstrings 
        parcounter(ij)=1; 
        parameters(ij).trace=0;
    end

    while( and( ~eof, ~header_end ) )
   
    byte_location = ftell(fid);  
    line = fgets(fid);
        
    for ij=1:nstrings
        if findstr(searchstring(ij).label,line)
            if (extract_num(line)) 
                b=findstr('LSB',line);
                 if (b>0)
                    parameters(ij).values(parcounter(ij))=extract_num(line(b(1):end));
                 else parameters(ij).values(parcounter(ij))=extract_num(line);
                 end
                
            else
                b= findstr(line,'"');
                if (b>0)  
                    parameters(ij).channel(parcounter(ij)).name=line(b(1)+1:b(2)-1); 
                else
                    if (findstr(line,'Trace')>0) parameters(ij).trace=1; end;
                end
            end
            parcounter(ij)=parcounter(ij)+1;
        end
    end
    
    if( (-1)==line )  eof  = 1;  
    end     
    if length( findstr( line, '\*File list end' ) ) header_end = 1;    
    end
    counter=counter+1;
    end
fclose(fid);      
return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


fclose('all');
return%main


