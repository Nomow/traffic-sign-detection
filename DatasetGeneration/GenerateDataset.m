directory = '/home/vtpc/Documents/Alvils/traffic-sign-detection/data/signs';
video = VideoReader('/home/vtpc/Documents/Alvils/traffic-sign-detection/data/videos/vid1.mp4');
path_to_data = "/home/vtpc/Documents/Alvils/traffic-sign-detection/data/datasets/";
path_to_annotations = path_to_data + "annotations/cropped.json";

annotations = LoadAnnotations(path_to_annotations);

video.CurrentTime = 0;
nb_of_frames = video.Duration * video.FrameRate;
frame_from = round(video.FrameRate * 10);
frame_to = round(nb_of_frames - video.FrameRate * 10);

object_imgs = LoadImgs(directory, 'jpg')
nb_of_classes = length(object_imgs)
nb_of_imgs_per_class = 10;

%% binarizes imgs
for i = 1:nb_of_classes
    binarized__object_imgs{i} = GetBinarizedImg(object_imgs{i}, 0.9);
end

%% adds categories
for i = 1:nb_of_classes
    categories = struct;
    categories.supercategory = string(i);
    categories.id = i;
    categories.keypoints = {};
    categories.name = string(i);
    categories.skeleton =  {};
    annotations.categories{end + 1} = categories;
end





%% generates dataset
black_rgb = [0 0 0]';
for i = 1:nb_of_classes
    object_img = object_imgs{i};
    object_binary_img = binarized__object_imgs{i};
    i
    for j = 1:nb_of_imgs_per_class
        %%  rotates 
        rotation_angle = randi([-35, 35]);
        rotated_img = RotateImg(object_img, rotation_angle);
        rotated_object_binary_img = RotateImg(object_binary_img, rotation_angle);
        %% shears 
        shear_angle_x = randi([-15, 15]);
        shear_angle_y = randi([-75, 75]);
        sheared_img = ShearImg(rotated_img, shear_angle_x, shear_angle_y);
        sheared_object_binary_img = ShearImg(rotated_object_binary_img, shear_angle_x, shear_angle_y);

        %% flips horizontal 
        flip_img = 0;
        flipped_img = FlipHorizontal(sheared_img, flip_img);
        flipped_object_binary_img = FlipHorizontal(sheared_object_binary_img, flip_img); 
        
 
        %% adjust brightness
        brightness_from = 0.5;
        brightness_to = 1.5;
        brightness_coeff = (brightness_to - brightness_from)* rand() + brightness_from;
        contrasted_img = AdjustBrightness(flipped_img, brightness_coeff);
        
        %% gets random frame of video
        random_frame_index = randi([frame_from frame_to]);
        frame = ReadVideoFrame(video, random_frame_index);
        
        %% crops frame
        cropped_frame = RndCrop(frame);
        
        %% flips horizontal frame     
        flip_frame = randi([0 1]);
        flipped_frame = FlipHorizontal(cropped_frame, flip_frame);

        [frame_height, frame_width, frame_dim] = size(cropped_frame);   
        
        %% gets size of sign       
        obj_height = size(flipped_object_binary_img, 1);
        obj_width = size(flipped_object_binary_img, 2);
        
        %% resizes based on bg img dims
        resize_coeff_from = 0.05;
        resize_coeff_to = 0.15;
        resize_coeff = (resize_coeff_to - resize_coeff_from)* rand() + resize_coeff_from;
        scaled_obj_img = ResizeBasedOnBackgroundSize(contrasted_img, resize_coeff, frame_width, frame_height);
        scaled_binary_obj_img = ResizeBasedOnBackgroundSize(flipped_object_binary_img, resize_coeff, frame_width, frame_height);
        
        %% blur
        blur_from = 0;
        blue_to = 1;
        blur_coeff = (blue_to - blur_from)* rand() + blur_from;
        blurred_obj_img = BlurImg(scaled_obj_img, blur_coeff);
        blurred_binary_obj_img = BlurImg(scaled_binary_obj_img, blur_coeff);
        blurred_binary_obj_img(blurred_binary_obj_img > 0.5) = 1;
        blurred_binary_obj_img(blurred_binary_obj_img < 0.5) = 0;  


        %% gets image pixels without backgroundtreshold_width_max
        img_data_index = find(blurred_binary_obj_img > 0);
        [row, col] = ind2sub(size(blurred_binary_obj_img), img_data_index);
        obj_height = size(blurred_binary_obj_img, 1);
        obj_width = size(blurred_binary_obj_img, 2);

        
        %% random tanslate
        [top_left_x, top_left_y] = TranslateRnd(frame_width, frame_height, obj_width, obj_height);
       
        %% augment
        augmented_frame = AugmentFrame(cropped_frame, blurred_obj_img, top_left_x, top_left_y, col, row);
        
        %% blurs augmented frame
        blur_from = 0;
        blue_to = 3;
        blur_coeff = (blue_to - blur_from)* rand() + blur_from;
        blurred_augmented_img = BlurImg(augmented_frame, blur_coeff);

        %% brightness adjusting
        brightness_from = 0.5;
        brightness_to = 1.5;
        brightness_coeff = (brightness_to - brightness_from)* rand() + brightness_from;
        contrasted_augmented_img = AdjustBrightness(blurred_augmented_img, brightness_coeff);

        %% caluclates bbox and adds to annotations file
        bbox = [top_left_x - 1, top_left_y - 1, obj_width, obj_height];
        annotations = AddAnnotations(annotations, contrasted_augmented_img, bbox, (i));   
        img_path = path_to_data + "cropped/" + annotations.images{end}.file_name;
        %% saves img
        imwrite(contrasted_augmented_img, img_path);
        if(mod(j, 10000) == 0)
            j
        end
    end
end

%% saves to json
fid = fopen(path_to_annotations,'w');
fprintf(fid, '%s', jsonencode(annotations));

fclose(fid);



