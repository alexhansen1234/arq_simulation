clc; clear all; close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameters %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

message_len     = 20;

window_len      = 10;

recv_buff       = 1;

p_corruption    = 0.2;

channel_delay   = 4;

timeout         = 10;

cost_per_idle   = 1;

cost_per_transmission = 10;

max_sim_time    = 1000;

%%%%%%%%%%%%%%%%%%%%%%%%%%
% End Parameters %%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

tx_array = int16.empty();
tx_packet.id        = 0;
tx_packet.time      = 0;
tx_packet.checked   = false;

rx_array = int16.empty();
rx_packet.id    = 0;

tx_ack_array = int16.empty();
tx_ack_packet.id    = 0;
tx_ack_packet.time  = 0;
tx_ack_packet.checked = false;

rx_ack_array = int16.empty();
rx_ack_packet.id = 0;

message = int16.empty();

sender_energy   = int16.empty();
receiver_energy = int16.empty();

sender_energy_inc   = 0;
receiver_energy_inc = 0;

clock = 0;

while( clock < max_sim_time )
    
    % Check for pending ACKs, and remove
    % ACK'd messages from tx array
    if( ~isempty(tx_ack_array) )
        for i = 1 : length(tx_ack_array)
            if(tx_ack_array(i).checked == true)
                continue;
            end
            
            if(clock - tx_ack_array(i).time < channel_delay)
                continue;
            end
            
            tx_ack_array(i).checked = true;
            
            if( rand(1) > p_corruption )
                rx_ack_packet.id = tx_ack_array(i).id;
                rx_ack_array = [rx_ack_array rx_ack_packet];
            else
                disp(['ACK ' num2str(tx_ack_array(i).id) ' Corrupted']);
            end
        end
    end
    
    if( ~ isempty(rx_ack_array) )
        highest_ack = 0;
        
        % Find highest ACK
        for i = 1 : length(rx_ack_array)
            highest_ack = max(highest_ack, rx_ack_array(i).id);
        end
        
        % Remove all messages with IDs less than or equal
        % to the highest ACK
        i = 1;
        while i <= length(tx_array)
            if( tx_array(i).id <= highest_ack )
                disp(['Received ACK ' num2str(tx_array(i).id) ', clock = ' num2str(clock)]);
                tx_array(i) = [];
                continue;
            end
            i = i + 1;
        end
        
        % If the value of tx_packet.id equals the message
        % length and the length of tx_array is zero, we've
        % finished transmission so we exit.
        if(tx_packet.id == message_len && isempty(tx_array))
            disp('Message successfully transmitted');
            break;
        end
    end
    
    if(length(tx_array) < window_len && tx_packet.id < message_len)
        % fill window until the entire message is initially transmitted
        tx_packet.id    = tx_packet.id + 1;
        tx_packet.time  = clock;
        tx_packet.checked = false;
        tx_array = [tx_array tx_packet];
        disp(['Transmitting ' num2str(tx_packet.id) ', clock = ' num2str(clock)]);
        sender_energy_inc = sender_energy_inc + cost_per_transmission;
    else
        % check retransmits
        for i = 1 : length(tx_array)
            if ( clock - tx_array(i).time >= timeout )
                tx_array(i).checked = false;
                tx_array(i).time    = clock;
                disp(['Retransmitting ' num2str(tx_array(i).id) ', clock = ' num2str(clock)]);
                sender_energy_inc = sender_energy_inc + cost_per_transmission;
            end
        end
    end
    
    % tx_array should always have atleast
    % one entry by this point
    for i = 1 : length(tx_array)
        
        % Only check unchecked messages
        if( tx_array(i).checked == true )
            continue;
        end
        
        % Only check messages which have arrived
        if( clock - tx_array(i).time < channel_delay)
            continue;
        end
        
        tx_array(i).checked = true;
        
        % Drop already completely accepted packets
        if( tx_array(i).id <= length(message) )
            continue;
        end
        
        % Drop packets which are in rx_array
        if( ~isempty(rx_array) )
            matched = false;
            
            for j = 1 : length(rx_array)
                if(tx_array(i).id == rx_array(j).id)
                    matched = true;
                    break;
                end
            end
            
            if(matched == true)
                continue;
            end
        end
        
        if( length(rx_array) == recv_buff-1)
            if( rand(1) > p_corruption && tx_array(i).id == length(message)+1 )
                rx_packet.id = tx_array(i).id;
                rx_array = [rx_array rx_packet];
                disp(['Received ' num2str(rx_packet.id) ', clock = ' num2str(clock)]);
            else    
                disp(['Dropped ' num2str(tx_array(i).id) ', clock = ' num2str(clock)]);
            end
            
            continue;
        end    
        
        % Probabilistically add packet to rx_array
        if( rand(1) > p_corruption && length(rx_array) < recv_buff)
            rx_packet.id = tx_array(i).id;
            rx_array = [rx_array rx_packet];
            disp(['Received ' num2str(rx_packet.id) ', clock = ' num2str(clock)]);
        else
            disp(['Packet ' num2str(tx_array(i).id) ' corrupted']);
        end
    end
    
    % add packets to message in order
    if( ~isempty(rx_array) )
        i = 1;
        while (i <= length(rx_array))
            if(rx_array(i).id == length(message) + 1)
                message = [message rx_array(i).id];
                rx_array(i) = [];
                i = 1;
            else
                i = i + 1;
            end
        end
    end
    
    % Prune ACK array
    if( ~isempty(tx_ack_array) )
        i = 1;
        while( i <= length(tx_ack_array) )
            if ( clock - tx_ack_array(i).time >= timeout && tx_ack_array(i).id < length(message) )
                tx_ack_array(i) = [];
            else
                i = i + 1;
            end
        end
    end
    
    % Check for highest ACK, if not the current message length
    % send ACK
    
    if( ~isempty(tx_ack_array) )
        highest_ack = 0;
        for i = 1 : length(tx_ack_array)
            highest_ack = max(highest_ack, tx_ack_array(i).id);
        end
        
        if(highest_ack < length(message))
            tx_ack_packet.id    = length(message);
            tx_ack_packet.time  = clock;
            tx_ack_packet.checked = false;
            tx_ack_array = [tx_ack_array tx_ack_packet];
            disp(['Transmit ACK ' num2str(tx_ack_packet.id) ', clock = ' num2str(clock)]);
            receiver_energy_inc = receiver_energy_inc + cost_per_transmission;
        else
            for i = 1 : length(tx_ack_array)
                if(tx_ack_array(i).id == highest_ack && clock - tx_ack_array(i).time >= timeout)
                    tx_ack_array(i).checked = false;
                    tx_ack_array(i).time    = clock;
                    disp(['Retransmit ACK ' num2str(tx_ack_array(i).id) ', clock = ' num2str(clock)]);
                    receiver_energy_inc = receiver_energy_inc + cost_per_transmission;
                    break;
                end
            end
        end
    end
    
    if( isempty(tx_ack_array) && ~isempty(message) )
        tx_ack_packet.id    = length(message);
        tx_ack_packet.time  = clock;
        tx_ack_packet.checked = false;
        tx_ack_array = [tx_ack_array tx_ack_packet];
        disp(['Transmit ACK ' num2str(tx_ack_packet.id) ', clock = ' num2str(clock)]);
        receiver_energy_inc = receiver_energy_inc + cost_per_transmission;
    end
    
    sender_energy_inc   = sender_energy_inc + cost_per_idle;
    receiver_energy_inc = receiver_energy_inc + cost_per_idle;
    
    sender_energy   = [sender_energy sender_energy_inc];
    receiver_energy = [receiver_energy receiver_energy_inc];
    
    sender_energy_inc = 0;
    receiver_energy_inc = 0;
    clock = clock + 1;
end

plot(cumsum(sender_energy)); 
hold on; 
plot(cumsum(receiver_energy));
title(['Energy Consumption in ARQ Protocol, N=' num2str(message_len) ', W=' num2str(window_len) ', R=' num2str(recv_buff), 'pc=' num2str(p_corruption)]);
xlabel('Time');
ylabel('Cumulative Energy Consumption');
legend('Sender', 'Receiver');
grid on;