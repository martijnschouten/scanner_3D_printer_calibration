function [std_result,mean_result] = visualise_optical_check(filename,locs,method, is_x)
    load(filename)
    for i1 = 1:5
        Y_avg_ind(i1) = locs(i1)*1e-3;
        Y_min_ind(i1) = 0;
        Y_max_ind(i1) = 0;
    end

    if is_x
        y_updown = x_offset_mat{method}(:,1:2:end)/2+x_offset_mat{method}(:,2:2:end)/2;
        y_avg = mean(y_updown);
        y_min = min(y_updown);
        y_max = max(y_updown);

        error = [];
        mean_offset = zeros(4,5);
        for i1 = 1:5
            %mean_offset(:,i1) = x_offset_mat{method}(:,i1*2-1)/2+x_offset_mat{method}(:,i1*2)/2;
            error = [error ;y_updown(:,i1)-locs(i1)*1e-3];
        end
    else
        y_updown = y_offset_mat{method}(:,1:2:end)/2+y_offset_mat{method}(:,2:2:end)/2;
        y_avg = mean(y_updown);
        y_min = min(y_updown);
        y_max = max(y_updown);

        error = [];
        mean_offset = zeros(4,5);
        for i1 = 1:5
            %mean_offset(:,i1) = y_offset_mat{method}(:,i1*2-1)/2+x_offset_mat{method}(:,i1*2)/2;
            error = [error ;y_updown(:,i1)-locs(i1)*1e-3];
        end
    end
    
    std_result = std(error);
    mean_result = mean(error);
    
    n=length(y_avg);

    y_avg_mat = zeros(n,1);
    y_std_mat = zeros(n,1);


    y_avg_mat(:,1) = y_avg;

    y_min_mat(:,1) = y_avg-y_min;

    y_max_mat(:,1) = y_max-y_avg;

    y_tot = zeros(n,2);
    y_avg_tot(:,1) = y_avg_mat;
    y_avg_tot(:,2) = Y_avg_ind;

    y_max_tot(:,1) = y_max_mat;
    y_max_tot(:,2) = Y_max_ind;

    y_min_tot(:,1) = y_min_mat;
    y_min_tot(:,2) = Y_min_ind;

    
  
    hb = bar(y_avg_tot*1e6);
    x = zeros(n,2);
    x(:,1) = hb(1).XData+hb(1).XOffset;
    x(:,2) = hb(2).XData+hb(2).XOffset;
    hold on
    er = errorbar(x,y_avg_tot*1e6,y_min_tot*1e6,y_max_tot*1e6, 'LineStyle','none');                          
    %xlabel('Nozzle')
    if is_x
        ylabel('Measured x offset (μm)')
    else
        ylabel('Measured y offset (μm)')
    end
    xlabel('Structure set')
    set(gca,'XTickLabel',{'1','2','3','4','5'});
end
