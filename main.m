close all;
clear all;

%% Reflection Separation Using Focus 
disp('Glow Removal Example');
I2 = im2double(imread('gonglu.png')); 
[H W D] = size(I2);
tic

[LB LR] = septRelSmo(I2, 2000, zeros(H,W,D), I2);

figure(1),
subplot 131, imshow(I2) , title('input');
subplot 132, imshow(LB*2), title('background'); 
subplot 133, imshow(LR*2), title('reflection');

figure; imshow(I2,'border','tight','InitialMagnification','fit');

ouput_file = 'Haze_Layer_1.png';
imwrite(2*LB,ouput_file,'png');
figure; imshow(ouput_file,'border','tight','InitialMagnification','fit');
ouput_file1 = 'Glow_Layer_1.png';
imwrite(2*LR,ouput_file1,'png');
figure; imshow(ouput_file1,'border','tight','InitialMagnification','fit');


haze_I = imread('Haze_Layer_1.png');
[height,width, color]= size(haze_I);

K = 900; %%%the number of super-pixels
%设定超像素紧凑系数
m_compactness = 20;
%转换到LAB色彩空间
cform = makecform('srgb2lab');       %rgb空间转换成lab空间 matlab自带的用法
img_Lab = applycform(haze_I, cform);    %rgb转换成lab空间
% imshow(img_Lab)
% %检测边缘
% img_edge = DetectLabEdge(img_Lab);
% imshow(img_edge)
%得到超像素的LABXY种子点信息
img_sz = height*width;
superpixel_sz = img_sz/K;
STEP = uint32(sqrt(superpixel_sz));
xstrips = uint32(width/STEP);
ystrips = uint32(height/STEP);
xstrips_adderr = double(width)/double(xstrips);
ystrips_adderr = double(height)/double(ystrips);
numseeds = xstrips*ystrips;
%种子点xy信息初始值为晶格中心亚像素坐标
%种子点Lab颜色信息为对应点最接近像素点的颜色通道值
kseedsx = zeros(numseeds, 1);
kseedsy = zeros(numseeds, 1);
kseedsl = zeros(numseeds, 1);
kseedsa = zeros(numseeds, 1);
kseedsb = zeros(numseeds, 1);
n = 1;
for y = 1: ystrips
    for x = 1: xstrips 
        kseedsx(n, 1) = (double(x)-0.5)*xstrips_adderr;
        kseedsy(n, 1) = (double(y)-0.5)*ystrips_adderr;
        kseedsl(n, 1) = img_Lab(fix(kseedsy(n, 1)), fix(kseedsx(n, 1)), 1);
        kseedsa(n, 1) = img_Lab(fix(kseedsy(n, 1)), fix(kseedsx(n, 1)), 2);
        kseedsb(n, 1) = img_Lab(fix(kseedsy(n, 1)), fix(kseedsx(n, 1)), 3);
        n = n+1;
    end
end
% n = 1;
%根据种子点计算超像素分区
klabels = PerformSuperpixelSLIC(img_Lab, kseedsl, kseedsa, kseedsb, kseedsx, kseedsy, STEP, m_compactness);


haze_I = double(haze_I);

SA_rgb=zeros(height,width,color);
spnum = max(klabels(:));	%superpixel 数量
for k = 1:color
	spmax = zeros(spnum,1);		%每个superpixel中的最大值
	for i = 1:height
		for j = 1:width
			if haze_I(i,j,k)> spmax(klabels(i,j))
			spmax(klabels(i,j)) = haze_I(i,j,k);	%如果大于最大值，更新最大值
			end
		end
	end

	for i = 1:height
		for j = 1:width
			SA_rgb(i,j,k) = spmax(klabels(i,j));	%为每个像素赋值
		end
	end
end



figure; imshow(SA_rgb/255,'border','tight','InitialMagnification','fit');

r = 60; %%%60;   
eps = 4096;%eps1*2^8*2^8;
A(:,:,1)= guidedfilter(haze_I(:,:,1), SA_rgb(:,:,1), r, eps);
A(:,:,2)= guidedfilter(haze_I(:,:,2), SA_rgb(:,:,2), r, eps);
A(:,:,3)= guidedfilter(haze_I(:,:,3), SA_rgb(:,:,3), r, eps);

figure; imshow(A/255,'border','tight','InitialMagnification','fit');

S_Dark = ones(max(max(klabels)),1)*256;

[dark_channel,haze_m]=Simplified_Dark_Channel(haze_I,A);

for i = 1:height
    for j = 1:width 
S_Dark(klabels(i,j))= min(S_Dark(klabels(i,j)),dark_channel(i,j));
    end
end

%%%The initial value of t(p)
t_p = zeros(height,width);
for i=1:height
    for j=1:width
        t_p(i,j) = 1-S_Dark(klabels(i,j));
    end
end
figure; imshow(t_p,'border','tight','InitialMagnification','fit');
imwrite(t_p,'nighttime_initial_Map.png','png');
%%%Refine the transmission map
r =20; %%%60;   
eps =1/1000;%eps1*2^8*2^8;
t = guidedfilter(haze_m, t_p, r, eps);
figure; imshow(t,'border','tight','InitialMagnification','fit');
imwrite(t,'nighttime_Map.png','png');


LOW=0.2;

%%% Recover the scene radiance
Z = zeros(height,width,color);
for i = 1:height
    for j = 1:width  
        for k = 1:color
            Z(i,j,k) = floor((haze_I(i,j,k)-A(i,j,k))/max(t(i,j),LOW)+A(i,j,k));
        end
    end
end
toc
time=toc;

figure; imshow(Z/255,'border','tight','InitialMagnification','fit');
imwrite(Z/255,'Nighttime_Dehaze.png','png');



