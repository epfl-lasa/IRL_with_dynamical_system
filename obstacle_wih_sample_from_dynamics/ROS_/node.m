function node(states, weight_in)

TRAIN_EVERY_TIME = false;
% TRAIN_EVERY_TIME = true;

% folderName = 'result/eight_subject/Jun_6_02/testd2/';
% folderName = 'result/eight_subject/Jun_12_02/testd2/';
folderName = 'result/temp/';

if nargin<1 % if there is a input argument, then skip the ROS node creation (if false)
    % create a ros node
    if(~exist('node1','var'))
%         node1 = robotics.ros.Node('/irl_parameter_update1','128.178.145.170');
        node1 = robotics.ros.Node('/irl_parameter_update1');
    end

    % matlab function for subscribing
    if(~exist('sub','var'))
        sub = robotics.ros.Subscriber(node1, ...
            '/motion_generator_to_parameter_update', 'geometry_msgs/PoseArray');
    end
    
     % matlab function for publish
    if(~exist('pub','var'))
        pub = robotics.ros.Publisher(node1, ...
            '/parameters_tuning', 'std_msgs/Float32MultiArray');
    end

    if(~exist('msg','var'))
        msg = rosmessage('std_msgs/Float32MultiArray');
    end
    
    states_ = cell(1,1);
    
    save_sf_rho = zeros(2,1);
    save_time_elapsed = zeros(1,1);
end

j = 1;
counter = zeros(8,1);
states_collect = cell(8,1);
weight_input = ones(1,1);
weight_input_collect = cell(8,1);
cc = 0; % the counter of counter 

while 1
if nargin < 1
    scandata = receive(sub);
    disp('got trajctory')
    tic

    str = scandata.Header.FrameId;
    str_expresion = regexp(str, '(\w+)\s+([\d\.]+)\s+(\d+)', 'tokens');
    str_weight = str_expresion{1}{2};
    str_indicator = str_expresion{1}{1};
    str_number_of_demo_until_test = str2double(str_expresion{1}{3});
    
    if str_weight == "" 
        weight_input(j,1) = 1;
        disp('No weight specified.')
    else
        weight_input(j,1) = 1 - str2double(str_weight); % 1 - p.p
        disp(['weight recieved : ', num2str(weight_input(j,1))])
    end
    
    % in case 0 weight received
    if weight_input(j,1) == 0
        weight_input(j,1) = 0.0001;
    end
    
    % unpack pose data to trajectory
    T = length(scandata.Poses);
    x = zeros(1,T); y = x; z = x;
    for i = 1:T
        x(i) = scandata.Poses(i).Position.X;
        y(i) = scandata.Poses(i).Position.Y;
        z(i) = scandata.Poses(i).Position.Z;
    end
    
%     figure;plot3(x, y, z);xlabel('x');ylabel('y');zlabel('z');
    
    states = zeros(T,2);

    if (contains(str_indicator, 'AB')) 
        for i = 1:T
            states(i,1) = scandata.Poses(i).Position.Y;
            states(i,2) = scandata.Poses(i).Position.Z;
        end

        if (~contains(str_indicator, 'obj')) % no object grabbed
            cc = 1;             
            disp('--- AB ---')
        else
            disp('--- AB with obejct ---')
            cc = 2;
        end
    elseif (contains(str_indicator, 'CD'))
        for i = 1:T
            states(i,1) = scandata.Poses(i).Position.Y;
            states(i,2) = scandata.Poses(i).Position.Z;
        end

        if (~contains(str_indicator, 'obj')) % no object grabbed
            disp('--- CD ---')
            cc = 3;             
        else
            disp('--- CD with object ---')
            cc = 4;
        end

    elseif (contains(str_indicator, 'AC'))
        state = zeros(T,3);
        for i = 1:T
            state(i,1) = scandata.Poses(i).Position.X;
            state(i,2) = scandata.Poses(i).Position.Y;
            state(i,3) = scandata.Poses(i).Position.Z;
        end

        states(:,1) = ((state(:,1) - state(1,1)).^2 + (state(:,2) - state(1,2)).^2).^(1/2) ;
        states(:,2) = state(:,3);

        if (~contains(str_indicator, 'obj')) % no object grabbed
            disp('--- AC ---')
            cc = 5;             
        else
            disp('--- AC with object ---')
            cc = 6;
        end
    elseif (contains(str_indicator, 'BD'))
        state = zeros(T,3);
        for i = 1:T
            state(i,1) = scandata.Poses(i).Position.X;
            state(i,2) = scandata.Poses(i).Position.Y;
            state(i,3) = scandata.Poses(i).Position.Z;
        end
        
        states(:,1) = ((state(:,1) - state(1,1)).^2 + (state(:,2) - state(1,2)).^2).^(1/2) ;
        states(:,2) = state(:,3);

%             angle = 45/180*pi;
%             rotation_matrix = [cos(angle), - sin(angle); sin(angle), cos(angle)];
%             states = states*rotation_matrix;

        if (~contains(str_indicator, 'obj')) % no object grabbed
            disp('--- BD ---')
            cc = 7;             
        else
            disp('--- BD with object ---')
            cc = 8;
        end
    end


    states_r = rescale(states, T, cc);
    states_tbl = subsample(states_r, T);

    counter(cc) = counter(cc) + 1;
    if counter(cc) == 1
        ss = cell(1,1);
        ss{1} = states_tbl;
        states_collect{cc} = ss;
        w = weight_input(j,1);
        weight_input_collect{cc} = w;
    else
        ss = states_collect{cc};
        ss{counter(cc)} = states_tbl;
        states_collect{cc} = ss;
        w = weight_input_collect{cc};
        w(counter(cc),1) = weight_input(j,1);
        weight_input_collect{cc} = w;
    end       

else 
    T = length(states);
    states_ = states;
    w = ones(T,1);
    if nargin > 1
        w = weight_in;
    end
    str_number_of_demo_until_test = 10;
    str_indicator = 'CD';
    ss = states_;
end

w_legend = w;

SIGMOID = 1;
if SIGMOID
    % sigmoid
    w = w*10;
    w = sigmoid(w,5,1);
end

% store
% save([folderName 'data_' num2str(j) '.mat'], 'states');
save([folderName 'data_' num2str(j) '.mat'], 'states_collect');
ss_params = struct( 'weight',          w,...
                     'num_train_demo', str_number_of_demo_until_test,...
                     'indicator',      str_indicator, ... % string
                     'folderName',     folderName,...
                     'weight_legend',  w_legend);

if (TRAIN_EVERY_TIME ||  length(ss) > str_number_of_demo_until_test )
    % [rho, sf] = obstacle_test(2,1,1,1,'sim', ss, w);
    [rho, sf] = obstacle_test(2,1,1,1,'sim', ss, ss_params);
    %     [rho, sf] = obstacle_test(2,1,1,1,'sim', states_, weight_input);
    % First parameter: 1 use ame, 2 use gpirl. [Tuning reminder]
    % Should be fixed to be 2.. ame performace is very poor
    
    msg.Data(1) = rho;
    msg.Data(2) = sf;
    % add flag
    msg.Data(3) = cc - 1;

    formatSpec = 'sending rho %4.2f and sf %4.2f .. \n';
    fprintf(formatSpec, rho, sf)

    save_sf_rho(:,j) = [sf; rho];

    if exist('pub','var')
        send(pub, msg);
    end
end

elapsedTime = toc;
fprintf('elapsed time : %4.2f \n', elapsedTime)

save_time_elapsed(1,j) = elapsedTime;
save_ = cell(1,2);
save_{1} = save_sf_rho;
save_{2} = save_time_elapsed;
save('save_.mat', 'save_');

j = j +1;

if nargin >= 1
    pause(1000)
end

end

end


function states_r = rescale(states, T, cc)
    % Raise error when empty data received
    if isempty(states)
        error('Empty demonstration provided.')
    end
    % resacle the states
    rangex = [min(states(:,1)) max(states(:,1))];
    rangey = [min(states(:,2)) max(states(:,2))];
    a = [abs(rangex(1)), 0];
%     if (cc == 1 || cc == 2)
    if (cc == 11 || cc == 12)
        states_r = (states+repmat(a,length(states),1))./abs(rangex(2)-rangex(1)).*12;
        % reverse x
        if (states_r(T,1) < states_r(1,1))
            states_r(:,1) = -states_r(:,1) + 12;
        end
        
        dd = -1 - states_r(1,1);
        states_r(:,1) = states_r(:,1) + dd;     
        dd = 4.2 - states_r(1,2);
        states_r(:,2) = states_r(:,2) + dd;     
    else
        states_r = (states+repmat(a,length(states),1))./abs(rangex(2)-rangex(1)).*10;
        % reverse x
        if (states_r(T,1) < states_r(1,1))
            states_r(:,1) = -states_r(:,1) + 10;
        end

        % figure;plot(states_r(:,1),states_r(:,2))

        % put the first point at 0,4.2
        dd = 4.2 - states_r(1,2);
        states_r(:,2) = states_r(:,2) + dd;        
    end

end


function states_tbl = subsample(states_r, T)
    % elongate the list before sub sampling
    % ...
    % sub sampleing
%     lll = 50; % set the length to be 50
    lll = floor(T/30); 
    index = linspace(lll, T-lll, 50);
    index = floor(index);
    states_tbl = states_r(index, :);
end


function [px,py,pz] = projection(a,b,c,d,x,y,z)
    % given an plane equation ax+by+cz=d, project points xyz onto the plane
    % return the coordinates of the new projected points
    % written by Neo Jing Ci, 11/7/18
    A=[1 0 0 -a; 0 1 0 -b; 0 0 1 -c; a b c 0];
    B=[x; y; z; d];
    X=A\B;
    px=X(1);
    py=X(2);
    pz=X(3);
end



%     if(~exist('sub_weight','var'))
%         sub_weight = robotics.ros.Subscriber(node1, ...
%             '/motion_generator_to_parameter_update_weight', 'std_msgs/Float32');
%     end    

    % one more message record the mouse, which is unneccessary for now.
%     if(~exist('sub_mouse','var'))
%         folderpath = "~/catkin_ws/src";
%         rosgenmsg(folderpath)
%        folderpath = "~//Downloads/Untitled Folder/";
%         sub_mouse = robotics.ros.Subscriber(node1, ...
%             '/mouse_message_update_to_irl', 'mouse_perturbation_robot/MouseMsgPassIRL');
%     end
