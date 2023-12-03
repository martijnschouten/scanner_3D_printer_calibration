classdef analyser
    properties
        %Properties of the structure. Copy these from the python script
        %used to generate the gcode for the print.
        
        structure_pitch = 0.00075;%Distance between the two straigt lines that are closest together in meters
        structure_period = 0.0035;%Period of the printed pattern in meters 
        structure_length = 0.07;%Length of a structure in meters (longitudinal direction)
        structure_width = 0.008;%Width of a structure in meters (transverse direction)
        structure_spacing = 0.003;%Spacing between the structures
        structure_spacing_to_square = 0.005%Spacing between the structre and the square surrounding it
        structure_length_margin = 0.03;%Acceptable error margin on the length of the structure in meters  
        structure_width_margin = 0.008;%Acceptable error margin for the width of the structure in meters 
        rotation = 15;%Rotation of the structure, used for making sure all the belts/lead screws are pre-loading

        
        box_x_margin = 0.02;%Acceptable error margin on the size of the box in the x direction in meters 
        box_y_margin = 0.02;%Acceptable error margin on the size of the box in the y direction in meters 
        box_line_self_start = 0.1;%Start position of the horizontal line that is being used
        box_line_self_stop = 0.9;%Stop position of the horizontal line that is being used
        box_line_other_stop = 0.1;%Maximum distance from the bottom part of the box where the algorithm will look for the horizontal line
        box_x = 0;%Size of the box in the x direction
        box_y = 0;%Size of the box in the y direction
        

        ver_x_ref_only_start = 0.0006;%Distance from the left size of the structure where the reference only part of the reference structure starts.
        ver_x_ref_only_stop = 0.0013;%Distance from the left size of the structure where the reference only part of the reference structure stops.
        ver_x_sig_only_start = 0.0006;%Distance from the right size of the structure where the reference only part of the calibration structure starts.
        ver_x_sig_only_stop = 0.0013;%Distance from the right size of the structure where the reference only part of the calibration structure starts.
        ver_x_use = 0.2;%Ratio of the total width of the structure to use for determining the offsets
        ver_y_use = 0.7;%Ratio of the total length of the structure to use for determining the offsets
    
        dpi = 1200;%DPI of the used scan
        spatial_average = 50;%Samples to used in the spatial average filter used to determine the location of the structures
        
    end
    properties(Access=private)
        structure_harmonic = 2;
        
        cor_dx = 0;%Width of one pixel in meters
        cor_dy = 0;%Height of one pixel in meters
        wn = 0;%Number of pixels of the image in the horizontal direction
        hn = 0;%Number of pixels of the image in the vertical direction
        n = -1;%Number of nozzles
    end
    methods
        function analyse_interlocked_differential(obj, folder,sample_name,orientation,nozzles,display_figures,fft_things)
            %analyse_interlocked_differential - Analayse an interlocked calibration pattern.
            %analyse_interlocked_differential(folder,sample_name,index,nozzles,display_figures,fft_things)
            %searches for a filenamed $sample_name$_$nozzles$-$orientation$.bmp in a folder called folder,
            %for example for a file named "example", printed using nozzles
            %1,2,3,4 and 5 and in orientation 1 should be called "example_12345-1.bmp".
            %display_figures determines if figures will be displayed
            %fft_things determines if an fft will be done of every column
            %of the image of only of the entire image.
            %The function has no output but instead saves a mat file with
            %two cell arrays x_offset_mat and y_offset_mat. Each cell
            %contains a matrix. Each row corresponds to a rotation and each
            %column corresponds to a structure. The results in different
            %cells are calculated using different algorithms:
            %offset{1}: 1st harmonic, fft quadrature detection
            %offset{2}: 2st harmonic, fft quadrature detection
            %offset{3}: 3st harmonic, fft quadrature detection
            %offset{4}: 4st harmonic, fft quadrature detection
            %offset{5}: correlation based algorithm
            %offset{1}: 1st harmonic, fir quadrature detection
            %offset{2}: 2st harmonic, fir quadrature detection
            %offset{3}: 3st harmonic, fir quadrature detection
            obj.n = length(nozzles);
            name = [folder, sample_name '_' strrep(num2str(nozzles), ' ', '') '-' num2str(orientation) '.bmp'];
            I = imread(name);

            savefilename = ['result_' sample_name '_' strrep(num2str(nozzles), ' ', '') '.mat'];
            disp(['working on: ' name])

            I = gpuArray(I);
            I = rgb2gray(I);

            %invert colors, then rotate image, then invert colors again.
            %inverting colors is necessary because the default background
            %color during rotations is black and the paper is white.
            I = 255-I;
            I = imrotate(I,obj.rotation,'bicubic');
            I = 255-I;

            %box detection
            if mod(orientation,2)==1
                obj.box_x = obj.box_height();
                obj.box_y = obj.box_width();
            else
                obj.box_y = obj.box_height();
                obj.box_x = obj.box_width();
            end

            %determine the number of pixels of the image and width per
            %pixel
            [obj.hn,obj.wn,~] = size(I);
            obj.cor_dx = 2.54e-2/obj.dpi;
            obj.cor_dy = 2.54e-2/obj.dpi;
            

            %determine the average color of this background
            average_color = squeeze(mean(I,[1,2])-15);

            
            
            %apply a spatial filter to remove some noise
            H = fspecial('average',obj.spatial_average);
            I_bw = imfilter(I,H);

            %find all locations that are darker that the average color
            I_bw = I_bw(:,:)<average_color+10;

            %find all connecting elements
            CC = bwconncomp(gather(I_bw));

            %find the location of the box
            [xbox, ybox,box_specs,xuse,yuse] = obj.find_box(CC);
            
            %only use the pixels that contain the box
            I_bw = I_bw(yuse,xuse);
            I = I(yuse,xuse);
            
            %find the bottom line of the box
            if orientation == 1 || orientation == 4
                condition3 =    xbox > box_specs(1)*obj.cor_dx+box_specs(3)*obj.cor_dx*obj.box_line_self_start &...
                                xbox < box_specs(1)*obj.cor_dx+box_specs(3)*obj.cor_dx*obj.box_line_self_stop &...
                                ybox < box_specs(2)*obj.cor_dy+box_specs(4)*obj.cor_dy*obj.box_line_other_stop;
            else
                condition3 =    xbox > box_specs(1)*obj.cor_dx+box_specs(3)*obj.cor_dx*obj.box_line_self_start &...
                                xbox < box_specs(1)*obj.cor_dx+box_specs(3)*obj.cor_dx*obj.box_line_self_stop &...
                                ybox > box_specs(2)*obj.cor_dy+box_specs(4)*obj.cor_dy*(1-obj.box_line_other_stop);
            end        

            xbox_line_bottom = xbox(condition3);
            ybox_line_bottom = ybox(condition3);

            %determine the rotation of the bottom line through curve
            %fitting
            c_bottom = polyfit(xbox_line_bottom,ybox_line_bottom,1);
            angle_bottom = atan(c_bottom(1))*180/pi;
            if display_figures
                figure
                plot(xbox_line_bottom,ybox_line_bottom,'.')
                hold on
                plot(xbox_line_bottom,xbox_line_bottom*c_bottom(1)+c_bottom(2))
                xlabel('x position (m)')
                ylabel('Line y location (m)')
                xlim([min(xbox_line_bottom),max(xbox_line_bottom)])
                set(gcf,'position',[300,300,250,200])
            end
            
            %rotate the image by the determined rotation such that it is
            %completely straight
            I_bw = imrotate(I_bw,angle_bottom,'bicubic','crop');
            I_rot = imrotate(I,angle_bottom,'bicubic','crop');
            
            
            %find the offsets of the image. Depending on the orientation,
            %the processing will be sligtly different
            if orientation == 1
                x_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'ascend',true,true);
                y_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'descend',true,false);
            elseif orientation == 2
                x_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'ascend',true,false);
                y_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'ascend',false,true);
            elseif orientation == 3
                x_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'descend',false,true);
                y_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'ascend',false,false);
            elseif orientation == 4
                x_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'descend', false, false);
                y_offset = obj.find_offsets_ver_interlocked(I_rot,I_bw,display_figures,fft_things,'descend', true,true);
            else
                error('unknown orientation')
            end
            
            %if no save file exists, create a new save file and give a
            %warnig
            if ~isfile(savefilename)
                disp('Could not find file')
                for i1 = 1:length(x_offset)
                    x_offset_mat{i1} = zeros(4,2*obj.n);
                    y_offset_mat{i1} = zeros(4,2*obj.n);
                end
                save(savefilename,'x_offset_mat','y_offset_mat')
            end

            %load the save file and save the offsets.
            load(savefilename)
            for i1 = 1:length(x_offset)
                x_offset_mat{i1}(orientation,:) = x_offset{i1};
                y_offset_mat{i1}(orientation,:) = y_offset{i1};
            end
            save(savefilename,'x_offset_mat','y_offset_mat' )
        end
        
        function reps = repetitions(obj)
            %repetitions - Number of repetitions of the repetitive calibration structures 
            reps = floor(obj.structure_length/obj.structure_pitch/2);
        end
        
        function width = effective_width(obj)
            %effective_width - Total effective width of all the calibration
            %structures, without the box
            one_dir_width = obj.n*(obj.structure_width+obj.structure_spacing)*2-obj.structure_spacing;
            effective_height = obj.repetitions()*obj.structure_pitch*2;
            width = one_dir_width+effective_height+obj.structure_spacing;
        end 
        
        function width = box_width(obj)
            %box_width - Calculates the width of the box
            width = obj.effective_width() + 2*obj.structure_spacing_to_square;
        end
        
        function height = effective_height(obj)
            %effective_height - Total effective height of all the calibration
            %structures, without the box
            one_dir_width = obj.n*(obj.structure_width+obj.structure_spacing)*2-obj.structure_spacing;
            effective_height = obj.repetitions()*obj.structure_pitch*2;
            height = max([one_dir_width, effective_height]);
        end 
        
        function height = box_height(obj)
            %box_height - Calculates the height of the box
            height = obj.effective_height() + 2*obj.structure_spacing_to_square;
        end  
        
        function [xbox,ybox,box_specs,xuse,yuse] = find_box(obj,CC)
            %find_box - Finds the location of the box.
            %find_box(CC) finds the box with CC the output bwconncomp. It
            %returns:
            %-xbox A vector with all the x positions of all points of the whole box
            %-ybox A vector with all the y positions of all points of the whole box
            %-box_specs A vector with the position and size of the box
            %-xuse A vector with all the indices in the x direction that contain the box
            %-yuse A vector with all the indices in the y direction that contain the box
            
            %check all connecting areas to see if they could be our box.
            boundingBox = regionprops(CC,'BoundingBox');
            boundingBox = struct2cell(boundingBox);
            
            for i1 = 1: length(boundingBox)
                width = boundingBox{i1}(:,3);
                height = boundingBox{i1}(:,4);
                condition(i1) =    width >  obj.box_x/obj.cor_dx - obj.box_x_margin/obj.cor_dx & ...
                                   width <  obj.box_x/obj.cor_dx + obj.box_x_margin/obj.cor_dx & ...
                                   height >  obj.box_y/obj.cor_dy - obj.box_y_margin/obj.cor_dy & ...
                                   height <  obj.box_y/obj.cor_dy + obj.box_y_margin/obj.cor_dy;
            end

            box_CC = CC;
            box_CC.PixelIdxList = CC.PixelIdxList(condition);
            box_CC.NumObjects = sum(condition);
            box_label = labelmatrix(box_CC);
            box_specs = boundingBox{condition};


            if box_CC.NumObjects > 1
                error('found more than one box')
            end
            
            %make matrix with all the x and y positions of the image
            cor_x = 0:obj.cor_dx:(obj.wn-1)*obj.cor_dx;
            cor_y = 0:obj.cor_dy:(obj.hn-1)*obj.cor_dy;
            cor_xcor = ones(obj.hn,1)*cor_x;
            cor_ycor = cor_y.'*ones(1,obj.wn);
            
            %get the coordinates of the box
            xbox = cor_xcor(box_CC.PixelIdxList{1});
            ybox = cor_ycor(box_CC.PixelIdxList{1});
            xuse = floor(box_specs(1)):ceil(box_specs(1))+ceil(box_specs(3));
            yuse = floor(box_specs(2)):ceil(box_specs(2))+ceil(box_specs(4));
        end
        
        function offset = find_offsets_ver_interlocked(obj,I_rot,I_bw,display_figs,fft_things,order,invert,ver)
            %find_offsets_ver_interlocked - Finds the offsets between the
            %interlocked calibration structures
            %find_offsets_ver_interlocked(I_rot,I_bw,display_figs,fft_things,order,invert,ver)
            %finds the offsets between the calirbation structures in the
            %color image I_rot using the binary image I_bw to locate the
            %structures. 
            %When display_figs is true it will show images
            %of the processing steps
            %When fft_things is true it will perform an fft each column.
            %When order is ascend it will assume that after rotation, the
            %left structure is the nozzle at position 1
            %When invert is true the found offsets will be inverted,
            %because after rotation the resulting structure is upside down
            %When ver is false the image will first be rotated by 90
            %degrees
            %This function returns a cell vector with a vector with the
            %offsets. The offset vector in each cell is determined using a
            %slightly different algorithm:
            %offset{1}: 1st harmonic, fft quadrature detection
            %offset{2}: 2st harmonic, fft quadrature detection
            %offset{3}: 3st harmonic, fft quadrature detection
            %offset{4}: 4st harmonic, fft quadrature detection
            %offset{5}: correlation based algorithm
            %offset{1}: 1st harmonic, fir quadrature detection
            %offset{2}: 2st harmonic, fir quadrature detection
            %offset{3}: 3st harmonic, fir quadrature detection
            
            %rotate the structure by 90 degree if it does not have the
            %right orientation
            if ~ver
               I_rot = rot90(I_rot);
               I_bw = rot90(I_bw);
            end
            
            %calculate new coordinate belonging to each pixel
            [hn2,wn2,~] = size(I_bw);
            cor2.dx = obj.cor_dx;
            cor2.dy = obj.cor_dy;
            cor2.x = 0:obj.cor_dx:(wn2-1)*cor2.dx;
            cor2.y = 0:obj.cor_dy:(hn2-1)*cor2.dy;
            cor2.xcor = ones(hn2,1)*cor2.x;
            cor2.ycor = cor2.y.'*ones(1,wn2);

            %find all connecting elements
            CC2 = bwconncomp(gather(I_bw));

            %find connecting elements that are to small and delete them.
            area = regionprops(CC2,'Area');
            area = cell2mat( struct2cell(area));
            condition = area > obj.structure_width*obj.structure_length*0.5;
            CC2.PixelIdxList = CC2.PixelIdxList(condition);
            CC2.NumObjects = sum(condition);
            label_mat = labelmatrix(CC2);
            
            %get the size and the centroid of the remaining elements
            boundingBox = regionprops(CC2,'BoundingBox');
            boundingBox = struct2cell(boundingBox);
            
            centroid = regionprops(CC2,'Centroid');
            centroid = struct2cell(centroid);
            
            
            if display_figs
                rect_fig = figure;
                imshow(I_rot)
            end

            %find the structures that the exactly the right size
            ver_x_loc = zeros(obj.n,1);
            ver_y_loc = zeros(obj.n,1);
            i2 = 0;
            for i1 = 1:CC2.NumObjects
                width = boundingBox{i1}(1,3);
                len = boundingBox{i1}(1,4);
                condition =    width >  obj.structure_width/cor2.dx - obj.structure_width_margin/cor2.dx & ...
                                   width <  obj.structure_width/cor2.dx + obj.structure_width_margin/cor2.dx & ...
                                   len >  obj.structure_length/cor2.dy - obj.structure_length_margin/cor2.dy & ...
                                   len <  obj.structure_length/cor2.dy + obj.structure_length_margin/cor2.dy;
                if condition
                    i2 = i2 + 1;
                    ver_x_loc(i2) = centroid{i1}(1);
                    ver_y_loc(i2) = centroid{i1}(2);
                end
            end

            %check if all the structures were found
            if i2 ~= 2*obj.n
                ver_x_loc
                figure
                imshow(I_bw)
                error("Could not find all of the vertical structures")
            end

            
            length_abs = obj.structure_length/cor2.dy;%length of a structure in pixels
            width_abs = obj.structure_width/cor2.dx;%length of a structure in pixels
            periods = round(obj.structure_length*(obj.ver_y_use)/obj.structure_period);%periods of the structure that will be used for determining the phase
            used_length_abs = round((periods*obj.structure_period)/cor2.dy);%length of the stucture used for determing the phase in pixels
                
            %Sort the locations of the structures in ascending or
            %descending order. 
            [ver_x_loc, I] = sort(ver_x_loc,order);
            ver_y_loc = ver_y_loc(I);
            
            
            if display_figs
                fft_fig = figure;
                ref_fig = figure;
                sig_fig = figure;
                ref_mod = figure;
                sig_mod = figure;
                ref_mod_fft = figure;
                sig_mod_fft = figure;
                original = figure;
            end
            for i1 = 1:2*obj.n
                %determine the x direction start and stop pixel of the
                %area that will be used for determining the offsets
                %(center red square)
                ver_x_start_abs = round(ver_x_loc(i1)-width_abs*obj.ver_x_use/2);
                ver_x_stop_abs = ver_x_start_abs+round(width_abs*obj.ver_x_use);
                
                %determine the x direction start and stop pixel of the
                %area that will be used for determining the offsets
                %(center red rectangle)
                ver_y_start_abs = round(ver_y_loc(i1)-length_abs*obj.ver_y_use/2);
                ver_y_stop_abs = ver_y_start_abs+used_length_abs;
                
                %determine the start and stop pixel of the area used to
                %determine the masks (left and right red rectangle). If the
                %order is different the red square for the reference will
                %be on the other side
                if strcmp(order, 'ascend')
                    ver_x_start_sig_only_abs = round(ver_x_loc(i1)-width_abs*0.5+obj.ver_x_sig_only_start/cor2.dx);
                    ver_x_stop_sig_only_abs = ver_x_start_sig_only_abs + round((obj.ver_x_sig_only_stop-obj.ver_x_sig_only_start)/cor2.dx);

                    ver_x_start_ref_only_abs = round(ver_x_loc(i1)+width_abs*0.5-obj.ver_x_ref_only_stop/cor2.dx);
                    ver_x_stop_ref_only_abs = ver_x_start_ref_only_abs + round((obj.ver_x_ref_only_stop-obj.ver_x_ref_only_start)/cor2.dx);
                    
                else
                    ver_x_start_sig_only_abs = round(ver_x_loc(i1)+width_abs*0.5-obj.ver_x_sig_only_stop/cor2.dx);
                    ver_x_stop_sig_only_abs = ver_x_start_sig_only_abs + round((obj.ver_x_sig_only_stop-obj.ver_x_sig_only_start)/cor2.dx);

                    ver_x_start_ref_only_abs = round(ver_x_loc(i1)-width_abs*0.5+obj.ver_x_ref_only_start/cor2.dx);
                    ver_x_stop_ref_only_abs = ver_x_start_ref_only_abs + round((obj.ver_x_ref_only_stop-obj.ver_x_ref_only_start)/cor2.dx);
                end
                
                %make a vector of all the y positions of this structure
                ver_y_vec{i1} = (ver_y_start_abs:ver_y_stop_abs)*cor2.dy;

                if display_figs
                    figure(rect_fig)
                    hold on;
                    rectangle('Position',[ver_x_start_abs,ver_y_start_abs,...
                                         (ver_x_stop_abs-ver_x_start_abs),(ver_y_stop_abs-ver_y_start_abs)],...
                             'LineWidth',1,'EdgeColor','r');
                    rectangle('Position',[ver_x_start_ref_only_abs,ver_y_start_abs,...
                                         (ver_x_stop_ref_only_abs-ver_x_start_ref_only_abs),(ver_y_stop_abs-ver_y_start_abs)],...
                             'LineWidth',1,'EdgeColor','r');
                    rectangle('Position',[ver_x_start_sig_only_abs,ver_y_start_abs,...
                                         (ver_x_stop_sig_only_abs-ver_x_start_sig_only_abs),(ver_y_stop_abs-ver_y_start_abs)],...
                             'LineWidth',1,'EdgeColor','r');
                end

                %store sthe image in every center rectangle in a seperate
                %matrix. 
                ver_mat{i1} = double(I_rot(ver_y_start_abs:ver_y_stop_abs, ver_x_start_abs:ver_x_stop_abs));
                %Calculate the mean value of each image along the horizontal direction.
                ver_vec{i1} = mean(ver_mat{i1},2);
                
                %store sthe image in every reference rectangle in a seperate
                %matrix. 
                ver_ref_only_mat{i1} = double(I_rot(ver_y_start_abs:ver_y_stop_abs, ver_x_start_ref_only_abs:ver_x_stop_ref_only_abs));
                %Calculate the mean value of each image along the horizontal direction.
                ver_ref_only_vec{i1} = mean(ver_ref_only_mat{i1},2);
                %Apply a moving average to 1d version of the image
                ver_ref_only_filt{i1} = movmean(ver_ref_only_vec{i1},round(obj.structure_pitch/cor2.dy));
                %Caclulate the mask, values above the average (=white)
                %become 1, values below the average (=black) become 0
                ver_ref_only_mask{i1} = ver_ref_only_filt{i1}>mean(ver_ref_only_filt{i1});
                
                if fft_things
                    %also calcuate the fft for every x position and not
                    %just for the mean in the x direction
                    ver_ref_only_mat_mod = ver_mat;
                    for i2 = 1:length(ver_ref_only_mat_mod{i1}(1,:))
                        ver_ref_only_mat_mod{i1}(ver_ref_only_mask{i1},i2) = max(ver_ref_only_filt{i1}(ver_ref_only_mask{i1}));
                    end
                    ver_ref_only_mat_mod_fft{i1} = fft(ver_ref_only_mat_mod{i1},[],1);
                end
                
                %store the 1d version of the center image in a seperate
                %matrix
                ver_ref_only_vec_mod{i1} = ver_vec{i1};
                %apply the mask, everywhere the reference image was white, the
                %center image will become white too.
                ver_ref_only_vec_mod{i1}(ver_ref_only_mask{i1}) = max(ver_ref_only_filt{i1}(ver_ref_only_mask{i1}));
                %do an fft of the masked image
                ver_ref_only_vec_mod_fft{i1} = fft(ver_ref_only_vec_mod{i1}.*hamming(length(ver_ref_only_vec_mod{i1})));
                
                %store the image in every signal rectangle in a seperate
                %matrix. The signal rectangle is the rectangle that was
                %printed using the nozzle of which the offset will be
                %determined relative to the reference nozzle.
                ver_sig_only_mat{i1} = double(I_rot(ver_y_start_abs:ver_y_stop_abs, ver_x_start_sig_only_abs:ver_x_stop_sig_only_abs));
                %Calculate the mean value of each image along the horizontal direction.
                ver_sig_only_vec{i1} = mean(ver_sig_only_mat{i1},2);
                %Apply a moving average to 1d version of the image
                ver_sig_only_filt{i1} = movmean(ver_sig_only_vec{i1},round(obj.structure_pitch/cor2.dy));
                %Caclulate the mask, values above the average (=white)
                %become 1, values below the average (=black) become 0
                ver_sig_only_mask{i1} = ver_sig_only_filt{i1}>mean(ver_sig_only_filt{i1});
                
                if fft_things
                    %also calcuate the fft for every x position and not
                    %just for the mean in the x direction
                    ver_sig_only_mat_mod = ver_mat;
                    for i2 = 1:length(ver_sig_only_mat_mod{i1}(1,:))
                        ver_sig_only_mat_mod{i1}(ver_sig_only_mask{i1},i2) = max(ver_sig_only_filt{i1}(ver_sig_only_mask{i1}));
                    end
                    ver_sig_only_mat_mod_fft{i1} = fft(ver_sig_only_mat_mod{i1},[],1);
                end
                
                %store the 1d version of the center image in a seperate
                %matrix
                ver_sig_only_vec_mod{i1} = ver_vec{i1};
                %apply the mask, everywhere the reference image was white, the
                %center image will become white too.
                ver_sig_only_vec_mod{i1}(ver_sig_only_mask{i1}) = max(ver_sig_only_filt{i1}(ver_sig_only_mask{i1}));
                %do an fft of the masked image
                ver_sig_only_vec_mod_fft{i1} = fft(ver_sig_only_vec_mod{i1}.*hamming(length(ver_sig_only_vec_mod{i1})));
                
                if fft_things
                    %also do a 2d fft of the center image
                    ver_mat_fft{i1} = fft(ver_mat{i1},[],1);
                    ver_vec_fft{i1} = fft(ver_vec{i1});
                end
                
                if display_figs
                    %plot the reference images
                    figure(ref_mod);
                    subplot(1,2*obj.n,i1);
                    imshow(ver_ref_only_mat_mod{i1},[]);
                    xlabel('x position (mm)')
                    ylabel('y position (mm)')

                    %plot the signal images
                    figure(sig_mod);
                    subplot(1,2*obj.n,i1);
                    imshow(ver_sig_only_mat_mod{i1},[]);
                    xlabel('x position (mm)')
                    ylabel('y position (mm)')
                    
                    %plot the center images
                    figure(original);
                    subplot(1,2*obj.n,i1);
                    imshow(ver_mat{i1},[]);
                    xlabel('x position (mm)')
                    ylabel('y position (mm)')
                    
                    if fft_things
                        %plot the 2d fft of the center image
                        figure(fft_fig);
                        subplot(1,2*obj.n,i1);
                        imshow(log10(abs(ver_mat_fft{i1})),[]);
                        xlabel('x position (mm)')
                        ylabel('k (1/mm)')
                        
                        %plot the 1d fft of each column of the reference
                        figure(ref_mod_fft);
                        subplot(1,2*obj.n,i1);
                        imshow(log10(abs(ver_ref_only_mat_mod_fft{i1})),[]);
                        xlabel('x position (mm)')
                        ylabel('k (1/mm)')
                        
                        %plot the 1d fft of each column of the signal
                        figure(sig_mod_fft);
                        subplot(1,2*obj.n,i1);
                        imshow(log10(abs(ver_sig_only_mat_mod_fft{i1})),[]);
                        xlabel('x position (mm)')
                        ylabel('k (1/mm)')
                    end

                    %plot the reference, the masked reference
                    %and the mask
                    figure(ref_fig);
                    subplot(2*obj.n,1,i1);
                    yyaxis left
                    plot(ver_y_vec{i1},ver_ref_only_vec{i1})
                    hold on
                    plot(ver_y_vec{i1},ver_ref_only_vec_mod{i1})
                    hold on
                    yyaxis right
                    plot(ver_y_vec{i1},ver_ref_only_mask{i1})
                    xlabel('y position (mm)')
                    ylabel('value')

                    %plot the signal, the masked signal signal
                    %and the mask
                    figure(sig_fig);
                    subplot(2*obj.n,1,i1);
                    yyaxis left
                    plot(ver_y_vec{i1},ver_sig_only_vec{i1})
                    hold on
                    plot(ver_y_vec{i1},ver_sig_only_vec_mod{i1})
                    hold on
                    yyaxis right
                    plot(ver_y_vec{i1},ver_sig_only_mask{i1})
                    xlabel('y position (mm)')
                    ylabel('value')
                end
            end

            
            n3 = length(ver_mat{1}(1,:));

            %calulate the bin size in k space
            L = (ver_y_stop_abs-ver_y_start_abs)*cor2.dy;
            dk = 1/L;
            
            %find the spatial frequency that we want to use. This can be the period
            %at which the structure repeats itself, or a higher harmonic of
            %that
            kncenter = round(obj.structure_harmonic/obj.structure_period/dk)+1;
            kndif = 6;
            knuse = kncenter-kndif:kncenter+kndif;
            
            
            if fft_things
                %calculate and plot the offset of each column of the signal 
                %masked center image to the averaged reference masked center
                %image
                
                if display_figs
                    offsets = figure;
                end
                for i1 = 1:2*obj.n
                    ref = ver_ref_only_vec_mod_fft{i1};
                    X{i1} = zeros(n3,1);
                    Y{i1} = zeros(n3,1);
                    XYangle{i1} = zeros(n3,1);
                    XYoffset{i1} = zeros(n3,1);
                    for i2 = 1:n3
                       sig = ver_sig_only_mat_mod_fft{i1}(:,i2);
                       XYoffset{i1}(i2) = obj.calculate_offset(ref(knuse),sig(knuse));
                    end
                    xpos = (1:n3)*cor2.dx;
                    c_fit = polyfit(xpos,XYoffset{i1},1);
                    angle_fit(i1) = atan(c_fit(1))*180/pi;

                    if display_figs
                        figure(offsets)
                        subplot(5,2,i1)
                        plot(xpos,XYoffset{i1})
                        hold on
                        plot(xpos,c_fit(2)+c_fit(1)*xpos)
                        xlabel('x position (mm)')
                        ylabel('Offset (mm)')
                    end
                end
                
                %calculate and plot the offset of each column of the signal 
                %masked center image to the corresponding column of the
                %reference masked center image
                if display_figs
                    offsets2 = figure;
                end
                for i1 = 1:2*obj.n
                    Sangle{i1} = zeros(n3,1);
                    Soffset{i1} = zeros(n3,1);
                    for i2 = 1:n3
                        ref_ref = ver_ref_only_mat_mod_fft{i1}(:,i2);
                        sig = ver_sig_only_mat_mod_fft{i1}(:,i2);
                        Soffset{i1}(i2) = obj.calculate_offset(ref_ref(knuse),sig(knuse));
                    end
                    if display_figs
                        xpos = (1:n3)*cor2.dx;
                        figure(offsets2)
                        subplot(2*obj.n,1,i1)
                        plot(xpos,Soffset{i1})
                        xlabel('x position (mm)')
                        ylabel('Angle (rad)')
                    end
                end
            end
%                  figure
            for i1 = 1:2*obj.n
                %calculate the offset for the first 4 harmonics using the
                %fft quadrature detection
                obj.structure_harmonic = 1;
                kncenter = round(obj.structure_harmonic/obj.structure_period/dk)+1;
                kndif = 6;
                knuse = kncenter-kndif:kncenter+kndif;
                offset{1}(i1) = obj.calculate_offset(ver_ref_only_vec_mod_fft{i1}(knuse),ver_sig_only_vec_mod_fft{i1}(knuse));

                obj.structure_harmonic = 2;
                kncenter = round(obj.structure_harmonic/obj.structure_period/dk)+1;
                kndif = 6;
                knuse = kncenter-kndif:kncenter+kndif;
                offset{2}(i1) = obj.calculate_offset(ver_ref_only_vec_mod_fft{i1}(knuse),ver_sig_only_vec_mod_fft{i1}(knuse));

                obj.structure_harmonic = 3;
                kncenter = round(obj.structure_harmonic/obj.structure_period/dk)+1;
                kndif = 6;
                knuse = kncenter-kndif:kncenter+kndif;
                offset{3}(i1) = obj.calculate_offset(ver_ref_only_vec_mod_fft{i1}(knuse),ver_sig_only_vec_mod_fft{i1}(knuse));

                obj.structure_harmonic = 4;
                kncenter = round(obj.structure_harmonic/obj.structure_period/dk)+1;
                kndif = 6;
                knuse = kncenter-kndif:kncenter+kndif;
                offset{4}(i1) = obj.calculate_offset(ver_ref_only_vec_mod_fft{i1}(knuse),ver_sig_only_vec_mod_fft{i1}(knuse));

                %calculate the offset using cross correlations
                offset{5}(i1) = obj.calculate_offset_cor(ver_y_vec{i1},ver_ref_only_vec_mod{i1},ver_sig_only_vec_mod{i1});
                
                %calculate the offset for the first 3 harmonics using the
                %fir quadrature detection
                obj.structure_harmonic = 1;
                offset{6}(i1) = obj.calculate_offset_fir(ver_y_vec{i1},ver_ref_only_vec_mod{i1},ver_sig_only_vec_mod{i1});

                obj.structure_harmonic = 2;
                offset{7}(i1) = obj.calculate_offset_fir(ver_y_vec{i1},ver_ref_only_vec_mod{i1},ver_sig_only_vec_mod{i1});

                obj.structure_harmonic = 3;
                offset{8}(i1) = obj.calculate_offset_fir(ver_y_vec{i1},ver_ref_only_vec_mod{i1},ver_sig_only_vec_mod{i1});

                if invert == true
                   for i2 = 1:length(offset)
                        offset{i2}(i1) = -1* offset{i2}(i1);
                   end
                end
            end
        end
        function offset = calculate_offset(obj,ref_fft,sig_fft)
           %calculate_offset - Calculates the offset between structures
           %using fft quadrature detection
           %calculate_offset(ref_fft,sig_fft) calculates the offset
           %between the two structures, where ref_fft and sig_fft are the
           %fft bins containing the harmonic that should be used for
           %determining the offset.
           
           
           sig_fft_inf = sig_fft(end:-1:1);
           ref_fft_inf = ref_fft(end:-1:1);
           H_ref_fft = -1i*ref_fft;
           H_ref_fft_inv = H_ref_fft(end:-1:1);

           n = length(sig_fft_inf);

           %do a convolution in the frequency domain, this is a
           %multiplication in the time domain
           ref_x_sig = conv(ref_fft,conj(sig_fft_inf))+conv(conj(ref_fft_inf),sig_fft);
           H_ref_x_sig = conv(H_ref_fft,conj(sig_fft_inf))+conv(conj(H_ref_fft_inv),sig_fft);
           ref_x_sig_2 = [ref_x_sig(n:end);ref_x_sig(1:n-1)];
           H_ref_x_sig_2 = [H_ref_x_sig(n:end);H_ref_x_sig(1:n-1)];
           
           %go from the frequency domain back to the time domain
           ref_x_sig_3 = ifft(ref_x_sig_2);
           H_ref_x_sig_3 = ifft(H_ref_x_sig_2);
           
           %ref_x_sig_3 should be real, but they can be some very small 
           %complex part due to numerical inaccuracies.
           X = real(ref_x_sig_3);
           Y = real(H_ref_x_sig_3);
           
           %calculate the angle using atan2
           angles = atan2(Y,X);
           
           %if an uneven harmonic is used the reference and signal it will be
           %measured that they are 180 degrees out of phase and this must
           %be compensated for
           if mod(obj.structure_harmonic,2) == 1
               angles = angles - pi;
           end
           
           for i1 = 1:length(angles)
               if angles(i1)<-pi
                   angles(i1) = angles(i1)+2*pi;
               end
           end
           
           %
           angle = mean(angles(3:end-2));
           offset = angle/2/pi*obj.structure_period/obj.structure_harmonic;
        end
        function offset = calculate_offset_cor(obj,yscale,ref_mod,sig_mod)
            %calculate_offset_cor - Calculates the offset between structures
            %using correlations
            %calculate_offset_cor(yscale, ref_mod,sig_mod) calculates the offset
            %between the two structures, where ref_fft and sig_fft are
            %vectors representing one column of the image (or the average in
            %the horizontal direction) and yscale contains the y coordinates of
            %the pixels in these images

            %interpolate the signals in order to get a higher resolution
            %during the correlation. also subtract the mean so the signal is
            %symmetric arround y=0
            interpolation = 10;
            n = length(yscale);
            dy = (max(yscale)-min(yscale))/n;
            ynew = min(yscale):dy/interpolation:max(yscale);
            nperiod = round(obj.structure_period/dy*interpolation);
            
            ref_mod_int = interp1(yscale,ref_mod,ynew);
            ref_mod_int = ref_mod_int-mean(ref_mod_int);
            sig_mod_int = interp1(yscale,sig_mod,ynew);
            sig_mod_int = sig_mod_int-mean(sig_mod_int);
            sig_mod_int = [sig_mod_int,sig_mod_int(1:nperiod)];
            
            %do the convolution, use the point where the convolution is
            %maximum to determine the offset
            conv_result = conv(sig_mod_int,ref_mod_int,'valid');
            [~,I] = max(conv_result);
            offset_temp = (I-nperiod/2)*dy/interpolation;
            offset = offset_temp;
        end
        function offset = calculate_offset_fir(obj,yscale,ref_mod,sig_mod)
            %calculate_offset_fir - Calculates the offset between structures
            %using correlations
            %calculate_offset_fir(yscale,ref_mod,sig_mod) calculates the offset
            %between the two structures, where ref_fft and sig_fft are
            %vectors representing one column of the image (or the average in
            %the horizontal direction) and yscale contains the y coordinates of
            %the pixels in these images

            %calculate the fir coefficients needed to filter out the
            %specific harmonic
            L = yscale(end)-yscale(1);
            dk = 1/L;
            n = length(yscale);
            dy = L/n;
            
            k_nyq = 1/dy/2;
            kdif = dk/k_nyq;
            kcenter = obj.structure_harmonic/obj.structure_period/k_nyq;

            b = fir1(300,[kcenter-kdif,kcenter+kdif],'bandpass');
            a = 1;
            
            %this selects a range containing an integer number of periods (to avoid
            %windowing
            n_per_period = round(obj.structure_period/obj.cor_dy);%pixels per period
            use_periods = floor(0.8*n/n_per_period);%integer number of periods (approximately cutting off the first and last 10% is cut-off)
            use = round(0.1*n):round(0.1*n)+use_periods*n_per_period;
            
            %do the filtering
            ref_mod_filt = filtfilt(b,a,gather(ref_mod));
            sig_mod_filt = filtfilt(b,a,gather(sig_mod));
            
            %do a hilbert transform to obtain the 90 degree phase shifted
            %version of the reference
            H_ref_mod_filt = imag(hilbert(ref_mod_filt));
            
            %determine the in and out of phase component using quadrature
            %detection
            in_phase = sum(sig_mod_filt(use).*ref_mod_filt(use));
            out_of_phase = sum(sig_mod_filt(use).*H_ref_mod_filt(use));
            angle = atan2(out_of_phase,in_phase);
            
            %if an uneven harmonic is used the reference and signal it will be
            %measured that they are 180 degrees out of phase and this must
            %be compensated for
            if mod(obj.structure_harmonic,2) == 1
               angle = angle - pi;
            end
           
            if angle<-pi
               angle = angle+2*pi;
            end
            offset = angle/2/pi*obj.structure_period/obj.structure_harmonic;
        end
        
    end
end