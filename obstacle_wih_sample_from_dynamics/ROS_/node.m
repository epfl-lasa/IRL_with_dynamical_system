function node(states, weight_in)

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

%     if(~exist('sub_weight','var'))
%         sub_weight = robotics.ros.Subscriber(node1, ...
%             '/motion_generator_to_parameter_update_weight', 'std_msgs/Float32');
%     end    
    
     % matlab function for publish
    if(~exist('pub','var'))
        pub = robotics.ros.Publisher(node1, ...
            '/parameters_tuning', 'std_msgs/Float32MultiArray');
    end

    if(~exist('msg','var'))
        msg = rosmessage('std_msgs/Float32MultiArray');
    end
    
    % one more message record the mouse, which is unneccessary for now.
%     if(~exist('sub_mouse','var'))
%         folderpath = "~/catkin_ws/src";
%         rosgenmsg(folderpath)
%        folderpath = "~//Downloads/Untitled Folder/";
%         sub_mouse = robotics.ros.Subscriber(node1, ...
%             '/mouse_message_update_to_irl', 'mouse_perturbation_robot/MouseMsgPassIRL');
%     end

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
        str_expresion = regexp(str, '(\w+)\s+(\d.+)', 'tokens');
        str_weight = str_expresion{1}{2};
        str_indicator = str_expresion{1}{1};
        if str_weight == ""
            weight_input(j,1) = 1;
        else
            weight_input(j,1) = 1 - str2double(str_weight); % 1 - 
            disp(['weight recieved : ', num2str(weight_input(j,1))])
        end
                
        % unpack pose data to trajectory
        T = length(scandata.Poses);
        if (contains(str_indicator, 'AB'))
            states = zeros(T,2);
            for i = 1:T
                states(i,1) = scandata.Poses(i).Position.Y;
                states(i,2) = scandata.Poses(i).Position.Z;
            end
            
            % store
            save(['data_' num2str(j) '.mat'], 'states');
            if (~contains(str_indicator, 'obs')) % no object grabbed
                cc = 1;             
            else
                cc = 2;
            end
        elseif (contains(str_indicator, 'CD'))
            for i = 1:T
                states(i,1) = scandata.Poses(i).Position.Y;
                states(i,2) = scandata.Poses(i).Position.Z;
            end
            
            if (~contains(str_indicator, 'obs')) % no object grabbed
                cc = 3;             
            else
                cc = 4;
            end

        elseif (contains(str_indicator, 'AC'))
            for i = 1:T
                states(i,1) = scandata.Poses(i).Position.X;
                states(i,2) = scandata.Poses(i).Position.Y;
            end
            angle = 45/180*pi;
            rotation_matrix = [cos(angle), - sin(angle); sin(angle), cos(angle)];
            states = states*rotation_matrix;
            
            if (~contains(str_indicator, 'obs')) % no object grabbed
                cc = 5;             
            else
                cc = 6;
            end
        elseif (contains(str_indicator, 'BD'))
            for i = 1:T
                states(i,1) = scandata.Poses(i).Position.X;
                states(i,2) = scandata.Poses(i).Position.Y;
            end
            
            states(:,1) = states(:,1) - states(1,1);
            states(:,2) = states(:,2) - states(1,2);
            
            angle = 45/180*pi;
            rotation_matrix = [cos(angle), - sin(angle); sin(angle), cos(angle)];
            states = states*rotation_matrix;
            
            if (states(floor(T*2/3),2)<states(1,2))
                states(:,2) = -states(:,2);
            end
            
            if (~contains(str_indicator, 'obs')) % no object grabbed
                cc = 7;             
            else
                cc = 8;
            end            
        end
        states_r = rescale(states, T);
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
            
%             states(i,1) = scandata.Poses(i).Position.X;
%             states(i,2) = scandata.Poses(i).Position.Y;
%             states(i,3) = scandata.Poses(i).Position.Z;
        
%         figure;plot(states(:,1), states(:,2))
%         figure;plot3(states(:,1), states(:,2), states(:,3))
                
    else 
        T = length(states);
        states_ = states;
        weight_input = ones(T,1);
        if nargin > 1
            weight_input = weight_in;
        end    
    end
    [rho, sf] = obstacle_test(2,1,1,1,'sim', ss, w);
%     [rho, sf] = obstacle_test(2,1,1,1,'sim', states_, weight_input);
    % First parameter: 1 use ame, 2 use gpirl. [Tuning reminder]
    % Should be fixed to be 2.. ame performace is very poor

    msg.Data(1) = rho;
    msg.Data(2) = sf;

    disp('sending')
    disp(rho)
    disp(sf)
    
    save_sf_rho(:,j) = [sf; rho];
    
    if exist('pub','var')
        send(pub, msg);
    end
    
    elapsedTime = toc
    
    save_time_elapsed(1,j) = elapsedTime;
    save_ = cell(1,2);
    save_{1} = save_sf_rho;
    save_{2} = save_time_elapsed;
    save('save_.mat', 'save_');
   
    j = j +1;
    if nargin >= 1
        pause(100000)
    end
end

end


function states_r = rescale(states, T)
    % Raise error when empty data received
    if isempty(states)
        error('Empty demonstration provided.')
    end
    % resacle the states
    rangex = [min(states(:,1)) max(states(:,1))];
    rangey = [min(states(:,2)) max(states(:,2))];
    a = [abs(rangex(1)), 0];
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


function states_tbl = subsample(states_r, T)
    % sub sampleing
    lll = 50; % set the length to be 50
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