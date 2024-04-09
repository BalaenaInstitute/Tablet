function dataseaov(INX)
%Data sheets on Windows tablet with MATLAB
%Flexible version
%Can read form definitions from Excel sheets
%By Hal Whitehead
%March 2019
%%% Modified by Wilfried Beslin
%%% July 2019
%%% Modified by Ana Eguiguren
%%% July 2023

%TO DO
%Save counts

close all hidden
clear global
global ni hh savdat elemk typdat pdat varn dst outfil numsheet presheet tqt aqt alpar empk
global RezeroStart IncrementStart DecrementCancel AddpreviousDone Coul qcode
global dtStyle dtStyleDisp

%%% define datetime format
dtStyle = 'dd/mm/yy hh:MM';
dtStyleDisp = 'dd mmm HH:MM:SS';

lq=ls('cparams.mat');
if exist('INX')|isempty(lq)%read in parameters from Excel file...
    %if none available, or input parameter (INX) entered
    %input parameters
    [Ftab,Ptab]=uigetfile({'*.xlsx','*.xls'},'Select form parameter file');
    T=readtable([Ptab Ftab],'readvariablenames',1,'Sheet','Forms');
    dst=T.dst;%Names of forms
    numsheet=T.numsheet;%Maximum number of sheets open for each form type
    presheet=T.presheet;%Prerequisite forms for each form
    empk=T.empk;%Which entry to emphasize initially for each form
    for k=1:length(dst)%For each form
        tt{k}=readtable([Ptab Ftab],'readvariablenames',1,'Sheet',dst{k});
        elemk{k}=tt{k}.elemk';%The entries for the form
        varn{k}=tt{k}.varn';%Data variable names for each entry
        typdat{k}=tt{k}.typdat';%Type of data for each entry
        %1 numeric: acceptable max and min
        %2 numeric: larger than previous entry (also max and min)
        %3 radiobutton
        %4 checkbox
        %5 listbox
        %6 string
        %7 String, pushbutton
        %8 Time added at end
        %9 Time automatically added at end
        qdat=tt{k}.pdat;%pdat are default inputs, max and min limits, etc.
        for i=1:length(qdat)
            if ~isempty(str2num(qdat{i}))
                pdat{k}{i}=str2num(qdat{i});
            else
                pdat{k}{i}=split(qdat{i},char(10));
            end
        end
    end
    %Information on counts (e.g. inex numbers and running totals)
    Qcount=readtable([Ptab Ftab],'readvariablenames',1,'Sheet','Counts');
    qcode=Qcount.Code;%Codes for each count used in pdat
    Restart=Qcount.Restart;%Zeros this count at turn on
    RezeroStart=Qcount.RezeroStart;%Zeros this count when this form starts
    IncrementStart=Qcount.IncrementStart;%Increments this count by one when this form starts
    DecrementCancel=Qcount.DecrementCancel;%Decrements this count by one when this form cancels
    AddpreviousDone=Qcount.AddpreviousDone;%Increments this count by previous entry when form done
    fsetitle=inputdlg('Title of set of forms','Title',1,{strtok(Ftab,'.')});%Title of setup
    fsetitle=fsetitle{1};
    save cparams fsetitle dst numsheet presheet empk elemk varn typdat pdat qcode Restart RezeroStart IncrementStart DecrementCancel AddpreviousDone
    nform=1;%New forms
else%Read in parameters from current MATLAB file
    load cparams
    nform=0;%Old forms
end
Coul=zeros(1,length(qcode));%Set counts to zero, may be overriden if old data imported
ni=length(dst);%Number of data sheets

axx1=-40;
alpar=[30 1200 1 1];%Alarm Parameters (may be overridden if old data are imported
   %How often alarm in mins
   %   frequency in hz
   %   alarm loudness
   %   alarm length in s
hh=figure('tag','bigw','Menubar','none','toolbar','none','dockcontrols','off','units','normalized','position',[0 0 1 0.6645]);
hend=uicontrol('style','pushbutton','units','normalized','String','End','position',[0 0 0.1 0.05],'fontsize',10,'fontunits','normalized','callback',@stop);
halarm=uicontrol('style','pushbutton','units','normalized','String','Set alarm','position',[0.4 0 0.2 0.05],'fontsize',10,'fontunits','normalized','callback',@alset);
htime=uicontrol('style','text','tag','timee','units','normalized','String',datestr(now,dtStyleDisp),'position',[0.80 0 0.2 0.05],'fontsize',10,'fontunits','normalized');
tqt=timer('period',0.5,'tag','settimer','executionmode','fixedrate','timerfcn',@settime);
aqt=timer('period',5,'tag','altimer','executionmode','fixedrate','timerfcn',@altimer);
start(tqt);
for i=1:ni
    h(i)=uicontrol('style','pushbutton','tag',['aa' num2str(i)],'units','normalized','String',dst{i},'position',[(i-1)/ni 0.85 1/ni 0.15],'fontsize',10,'fontunits','normalized','callback',@dsrun);
    tab(i)=uicontrol('style','pushbutton','tag',['tabaa' num2str(i)],'units','normalized','String','Data','position',[(i-1)/ni 0.95 1/(3*ni) 0.06],...
        'fontsize',9,'fontunits','normalized','callback',{@showtable,i},'backgroundcolor',[0.8400 0.8400 0.8400]);
    savdat{i}={};%Data to be saved initially empty; may be overrridden if old data imported
end
if ~nform%Only if using old forms
    reuseq=questdlg({['Using: ' fsetitle],'Data storage:'},'Data storage','Add to previous data?','Start new files?','Add to previous data?');%Reuse previous data
    if strcmp(reuseq,'Add to previous data?')
        pq=dir('formdat*.mat');
        pqq={pq.name};
        [a1,a2]=max(cell2mat({pq.datenum}));
        if ~isempty(pq)
            load(pqq{a2});%adds last data set, plus counts, plus alarm data
            Coul(find(Restart))=0;%Zero counts at turn on
        end
    end
end
start(aqt);%Start alarms
outfil=['formdat' datestr(now,'YYmmddhhMM')];%Output files
pq=dir('formdat*.mat');
pqq={pq.name};
while sum(strcmp(pqq,outfil))
    outfil=[outfil 'a'];
end

function settime(obj,eventdata)%Sets time display
global dtStyleDisp
set(findobj('tag','timee'),'String',datestr(now,dtStyleDisp))


function altimer(obj,eventdata)%Runs alarms
global axx1 alpar
fs=8192;
warntime=alpar(1);fr=alpar(2);loud=alpar(3);allength=alpar(4);
axx=floor(20*mod((now-floor(now))*24*60,warntime)/warntime);
if axx<axx1
    sound(loud*sin((1:(fs*allength))*2*fr*pi/(fs)));
end
axx1=axx;

function alset(obj,eventdata)%Sets alarm parameters
global alpar
aqw=inputdlg({'How often (min)?','Fr (Hz)?','Loudness','Duration (s)'},'Alarm',1,{num2str(alpar(1)),num2str(alpar(2)),num2str(alpar(3)),num2str(alpar(4))});
alpar=[str2num(aqw{1}) str2num(aqw{2}) str2num(aqw{3}) str2num(aqw{4})];


function showtable(obj,eventdata,dss)%Shows data as table
global tt savdat varn
if isempty(findobj('tag','ttxx'))
    tt=uitable(gcf,'data',savdat{dss},'columnname',varn{dss},'tag','ttxx','units',...
        'normalized','position',[0.1 0.1 0.7 0.7],'columneditable',true);
    tts=uicontrol(gcf,'style','pushbutton','string','Save changes?','tag','ttxxs','units',...
        'normalized','position',[0.8 0.5 0.06 0.04],'callback',{@savtab,dss,1});
    ttc=uicontrol(gcf,'style','pushbutton','string','Cancel','tag','ttxxc','units',...
        'normalized','position',[0.8 0.45 0.06 0.04],'callback',{@savtab,dss,0});
    ttr=uicontrol(gcf,'style','pushbutton','string','Delete row','tag','ttxxr','units',...
        'normalized','position',[0.8 0.40 0.06 0.04],'callback',{@addrow,dss,1});
    tta=uicontrol(gcf,'style','pushbutton','string','Add row','tag','ttxxa','units',...
        'normalized','position',[0.8 0.35 0.06 0.04],'callback',{@addrow,dss,2});
end

function savtab(obj,eventdata,dss,whattodo)
%saves data from table
global savdat
if whattodo
    savdat{dss}=get(findobj('tag','ttxx'),'data');
    savedata;
end
delete(findobj('tag','ttxx'))
delete(findobj('tag','ttxxs'))
delete(findobj('tag','ttxxc'))
delete(findobj('tag','ttxxr'))
delete(findobj('tag','ttxxa'))


function addrow(obj,eventdata,dss,whattodo)
%adds or deletes row from table
global savdat
titid={'Delete which row (number)?','Add after which row (number)?'};
savdat{dss}=get(findobj('tag','ttxx'),'data');
dwr=inputdlg(titid{whattodo});
if isempty(dwr)
    return
end
dwrr=round(str2num(dwr{1}));
datle=length(savdat{dss}(:,1));
if (dwrr<(2-whattodo))|(dwrr>datle)
    warndlg('Bad line number');
    return
end
switch whattodo
    case 1%
        awwn=questdlg(['Are you sure you want to delete row ' num2str(dwrr)]);
        if strcmp(awwn,'Yes');
            savdat{dss}=savdat{dss}([1:(dwrr-1) (dwrr+1):end],:);
        end
    case 2%delete row
        aqqs=savdat{dss}(1,:);aqqs(1:length(aqqs))={[]};
        savdat{dss}=[savdat{dss}(1:dwrr,:); aqqs;savdat{dss}(dwrr+1:datle,:)];
end
set(findobj('tag','ttxx'),'Data',savdat{dss})


function savedata
%saves data to files
global savdat varn dst outfil alpar Coul
save(outfil,'savdat','alpar','Coul');
for dss=1:length(dst)
    if ~isempty(savdat{dss})
        warning off
        writetable(cell2table([varn{dss};savdat{dss}]),[outfil '.xlsx'],'sheet',dst{dss},'WriteVariableNames',false);
        warning on
    end
end


function stop(src,event)%Stops programme
global ni tqt aqt
OK=1;
for i=1:ni
    if length(findobj('tag',['xxxx' num2str(i)]));OK=0;end
end
if OK
    ans=questdlg('Are you sure you want to end?');
    if strcmp(ans,'Yes');
        warning off
        delete(tqt)
        delete(aqt)
        warning on
        close all;
    end
else
    warndlg('Close all windows before exiting')
            for i=1:ni%Makes windows visible
            hhhf=findobj('tag',['xxxx' num2str(i)]);
            for k=1:length(hhhf);figure(hhhf(k));end
            end
        
end

function cancelx(aarc,event,xname,dss)%Cancels input
global DecrementCancel Coul
ans=questdlg('Are you sure you want to cancel?');
src=findobj('tag',['aa' num2str(dss)]);
if strcmp(ans,'Yes')
    Coul(find(DecrementCancel==dss))=Coul(find(DecrementCancel==dss))-1;%Decrements counts
    close(aarc.Parent);
    hhf=length(findobj('tag',['xxxx' num2str(dss)]));
    if ~hhf
        src.BackgroundColor=[0.9400 0.9400 0.9400];
    end

end

function dsrun(src, event)%Inputs data
global dst ni hh savdat elemk typdat pdat numsheet presheet empk qcode
global RezeroStart IncrementStart Coul plcoul
global dtStyle
src.BackgroundColor=[0 1 0];
dss=str2num(src.Tag(3:end));
numel=length(elemk{dss});
timstart=now;
rowht=0.07;%Row height
fsi=11;%Default fontsize
if presheet(dss)
    if ~length(findobj('tag',['xxxx' num2str(presheet(dss))]))%Prerequisite sheet not open
        warndlg(['Need ' dst{presheet(dss)} ' sheet open first'])
        for i=1:ni%Makes windows visible
            hhhf=findobj('tag',['xxxx' num2str(i)]);
            for k=1:length(hhhf);figure(hhhf(k));end
        end
        src.BackgroundColor=[0.94 0.94 0.94];
        return
    end
end
hhf=length(findobj('tag',['xxxx' num2str(dss)]));
if hhf>=numsheet(dss)%Too many sheets of this type
    for i=1:ni%Makes windows visible
        hhhf=findobj('tag',['xxxx' num2str(i)]);
        for k=1:length(hhhf);figure(hhhf(k));end
    end
    src.BackgroundColor=[0.94 0.94 0.94];
    return
end
Coul(find(RezeroStart==dss))=0;%Zeros counts which start at this turn on
Coul(find(IncrementStart==dss))=Coul(find(IncrementStart==dss))+1;%increments counts
lineneed=1+(typdat{dss}>2)+((cellfun(@length,pdat{dss}).*((typdat{dss}==4)|(typdat{dss}==3)))>3)-(typdat{dss}==8)-(typdat{dss}==8);%lines needed
lineneed(typdat{dss} == 10) = 3; %%% modify lines needed for data type 10
lnn=1+[0 cumsum(lineneed)];
lnn=[lnn max(lnn)+1];
tln=max(lnn)+1;
wpo=get(findobj('tag','bigw'),'position');
hi=figure('Menubar','none','toolbar','none','tag',['xxxx' num2str(dss)],'units','normalized','name',src.String,'numbertitle','off',...
    'position',[wpo(1)+wpo(3)*(0.01+0.95*(dss-1)/ni) wpo(2)+wpo(4)*(0.02+0.02*hhf) 2*wpo(3)/ni 0.75*wpo(4)*min(tln/18,1)],'windowstyle','normal');
for i=1:ni%Makes windows visible
    hhhf=findobj('tag',['xxxx' num2str(i)]);
    for k=1:length(hhhf);figure(hhhf(k));end
end
for k=1:numel
    if (typdat{dss}(k)~=8)&(typdat{dss}(k)~=9)
        fq(k)=uicontrol(hi,'units','normalized','position',[0.04 1-lnn(k)/tln 0.92 0.8/tln],...
            'style','text','string',[elemk{dss}{k} ':'],'fontsize',fsi,'foregroundcolor','b');
        switch typdat{dss}(k)
            case 3%radiobutton
                i0=length(pdat{dss}{k})>3;
                bg(k)=uibuttongroup(hi,'position',[0.04 1-(lnn(k)+1+i0)/tln 0.92 0.8*(1+i0)/tln],'units','normalized');
                for i=1:length(pdat{dss}{k})
                    ij=i>3;
                    bgg(k,i)=uicontrol(bg(k),'tag',['xw_' num2str(dss) '_' num2str(k) '_' num2str(i)],'units','normalized',...
                        'style','radiobutton','string',pdat{dss}{k}{i},'position',[0.0+0.96*(i-3*ij-1)/max(3,(length(pdat{dss}{k})*i0-3)) 0.1+i0*(1-ij)*0.5 0.92 0.75/(1+i0)],'fontsize',fsi);
                end
            case 4%checkbox
                i0=length(pdat{dss}{k})>3;
                for i=1:length(pdat{dss}{k})
                    ij=i>3;
                    bg(k)=uicontrol(hi,'units','normalized','position',...
                        [0.04+0.96*(i-3*ij-1)/max(3,(length(pdat{dss}{k})*i0-2)) 1-(lnn(k)+1+ij)/tln 0.92 0.8/tln],...
                        'tag',['xw_' num2str(dss) '_' num2str(k) '_' num2str(i)],'style','checkbox','string',pdat{dss}{k}{i},'fontsize',fsi);
                end
            case 5%popup
                bg(k)=uicontrol(hi,'units','normalized','position',[0.04 1-(lnn(k)+1)/tln 0.92 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k)],'style','popup','string',pdat{dss}{k},'fontsize',fsi,'callback',@otherenter);
            case 6%string
                defstr=pdat{dss}{k};
                defstr=strrep(defstr,'**datest',datestr(now,dtStyle));
                bg(k)=uicontrol(hi,'units','normalized','position',[0.04 1-(lnn(k)+1)/tln 0.92 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k)],'style','edit','string',defstr,'fontsize',fsi);
            case 7%string, pushbutton
                for i=1:length(pdat{dss}{k})
                    uicontrol(hi,'units','normalized','position',[0.04+0.1*(i-1) 1-(lnn(k)+1)/tln 0.1 1/tln],...
                        'tag',['xw_' num2str(dss) '_' num2str(k) '_' num2str(i)],'style','pushbutton','string',pdat{dss}{k}{i},'fontsize',floor(0.8*fsi),'callback',@fladd)
                end
                bg(k)=uicontrol(hi,'units','normalized','position',[0.05+0.1*length(pdat{dss}{k}) 1-(lnn(k)+1)/tln 0.87-0.08*length(pdat{dss}{k}) 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k)],'style','edit','string',' ','fontsize',fsi);
            case 10 %%% GPS - added by Wilfried
                %%% [pushbutton] Update (press to update GPS reading)
                uicontrol(hi,'units','normalized','position',[0.80 1-lnn(k)/tln 0.16 0.8/tln],...
                        'tag',['xw_' num2str(dss) '_' num2str(k) '_1'],'style','pushbutton','string','Update','fontsize',floor(0.8*fsi),'callback',@GPSButton)
                %%%%%% LATITUDE
                %%% [static] "Lat" text
                uicontrol(hi,'units','normalized','position',[0.04 1-(lnn(k)+1)/tln 0.15 1/tln],...
                    'style','text','string','Lat:','fontsize',fsi,'foregroundcolor','b');
                %%% [edit] Lat degrees
                bg(k)=uicontrol(hi,'units','normalized','position',[0.22 1-(lnn(k)+1)/tln 0.15 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k) '_2'],'style','edit','string','','fontsize',fsi);
                %%% [static] "Degrees" symbol
                uicontrol(hi,'units','normalized','position',[0.38 1-(lnn(k)+1)/tln 0.02 1/tln],...
                    'style','text','string',char(176),'fontsize',fsi,'foregroundcolor','b');
                %%% [edit] Lat decimal minutes
                bg(k)=uicontrol(hi,'units','normalized','position',[0.42 1-(lnn(k)+1)/tln 0.38 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k) '_3'],'style','edit','string','','fontsize',fsi);
                %%% [popup] Lat hemisphere
                bg(k)=uicontrol(hi,'units','normalized','position',[0.82 1-(lnn(k)+1)/tln 0.14 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k) '_4'],'style','popupmenu','string',{' ','N','S'},'fontsize',fsi);
                %%%%%% LONGITUDE
                %%% [static] "Long" text
                uicontrol(hi,'units','normalized','position',[0.04 1-(lnn(k)+2)/tln 0.16 1/tln],...
                    'style','text','string','Long:','fontsize',fsi,'foregroundcolor','b');
                %%% [edit] Long degrees
                bg(k)=uicontrol(hi,'units','normalized','position',[0.22 1-(lnn(k)+2)/tln 0.15 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k) '_5'],'style','edit','string','','fontsize',fsi);
                %%% [static] "Degrees" symbol
                uicontrol(hi,'units','normalized','position',[0.38 1-(lnn(k)+2)/tln 0.02 1/tln],...
                    'style','text','string',char(176),'fontsize',fsi,'foregroundcolor','b');
                %%% [edit] Long decimal minutes
                bg(k)=uicontrol(hi,'units','normalized','position',[0.42 1-(lnn(k)+2)/tln 0.38 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k) '_6'],'style','edit','string','','fontsize',fsi);
                %%% [popup] Long hemisphere
                bg(k)=uicontrol(hi,'units','normalized','position',[0.82 1-(lnn(k)+2)/tln 0.14 0.8/tln],...
                    'tag',['xw_' num2str(dss) '_' num2str(k) '_7'],'style','popupmenu','string',{' ','E','W'},'fontsize',fsi);
                
            otherwise
                def=pdat{dss}{k};
                if iscell(def); def=def{1};end
                if ischar(def) || isstring(def) %%% BUGFIX by WB - added "isstring" check, because it seems cparams may store data in eithr "char" or "string" data type depending on MATLAB version
                    for ii=1:length(qcode)
                        if ~isempty(strfind(def,qcode{ii}))
                            def=num2str(Coul(ii));
                            plcoul(ii,:)=[dss k];%Place of total
                        end
                    end
                else
                    if length(def)==3%default value
                        def=num2str(def(3));
                    else
                        def='';
                    end
                end
                bg(k)=uicontrol(hi,'units','normalized','tag',['xw_' num2str(dss) '_' num2str(k)],'string',def,'position',[0.80 1-lnn(k)/tln 0.16 0.8/tln],'style','edit','fontsize',fsi);
                set(fq(k),'position',[0.04 1-lnn(k)/tln 0.72 0.8/tln]);
        end
    end
end
hdone=uicontrol(hi,'style','pushbutton','string','DONE','units','normalized',...
    'position',[0.1 0.03 0.35 2/tln],'BackgroundColor',[0.7 0.8 0.8],'callback',{@checkx,dss});
hcancel=uicontrol(hi,'style','pushbutton','string','CANCEL','units','normalized',...
    'position',[0.55 0.03 0.35 2/tln],'BackgroundColor',[0.7 0.8 0.8],'callback',{@cancelx,src.String,dss});
if empk(dss)
    uicontrol(bg(empk(dss)));
end

function checkx(qqrr,event,dss)%Checks and saves input
global ni hh savdat elemk typdat pdat varn encn
global AddpreviousDone RezeroStart Coul plcoul
global dtStyle
qqrc=get(qqrr,'parent');
src=findobj('tag',['aa' num2str(dss)]);
numel=length(elemk{dss});
badd=zeros(1,numel);
addend=0;
for k=1:numel
    switch typdat{dss}(k) %Type of entry   
         case 1%1 numeric: acceptable max and min
            aqk=get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'string');
            if iscell(aqk);aqk=aqk{1};end
            if strncmp(pdat{dss}{k},'*',1)%encounter/cluster/total coda numbers are OK is OK
                vaqk=str2num(aqk);
            else
                if ~strcmp(aqk,'-')%- is OK
                    vaqk=str2num(aqk);
                    if isempty(vaqk)
                        badd(k)=1;
                    end
                    if (vaqk<pdat{dss}{k}(1))|(vaqk>pdat{dss}{k}(2))
                        badd(k)=1;
                    end
                else
                    vaqk=NaN;
                end
            end
            datar{k}=vaqk;
        case 2    %2 numeric: larger than previous entry (also max and min)
            aqk=get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'string');
            if ~strcmp(aqk,'-')%- is OK
                vaqk=str2num(aqk);
                if isempty(vaqk)
                    badd(k)=1;
                end
                if (vaqk<pdat{dss}{k}(1))|(vaqk>pdat{dss}{k}(2))|vaqk<datar{k-1}
                    badd(k)=1;
                end
            else
                vaqk=NaN;
            end
            datar{k}=vaqk;
        case 3    %3 radiobutton
            xqq=' ';
            for i=1:length(pdat{dss}{k})
                if get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_' num2str(i)]),'value')
                    xqq=[xqq ' ' pdat{dss}{k}{i}];
                end
            end
            datar{k}=strip(xqq);
        case 4    %4 checkbox
            xqq=' ';
            for i=1:length(pdat{dss}{k})
                if get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_' num2str(i)]),'value')
                    xqq=[xqq ' ' pdat{dss}{k}{i}];
                end
            end
            datar{k}=strip(xqq);
        case 5    %5 popup
            ssq=get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'style');
            switch ssq
                case 'popupmenu'
                    datar{k}=pdat{dss}{k}{get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'value')};
                case 'edit'
                    datar{k}=get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'string');
            end
        case 6    %6 string
            datxx=get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'string');
            if iscell(datxx);datxx=datxx{1};end
            datar{k}=datxx;
        case 7    %7 string plus pushbutton
            datxx=get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'string');
            if iscell(datxx);datxx=datxx{1};end
            datar{k}=datxx;
        case 8    %8 Time manually added at end
            addend=1;
            addendk=k;
            askadd=1;
        case 9    %9 Time automatically added at end
            addend=1;
            addendk=k;
            askadd=0;
        case 10     %%% GPS coordinates
            datxx = struct();
            datxx.LatDeg = get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_2']),'string');
            datxx.LatMin = get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_3']),'string');
            datxx.LatHem = get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_4']),'string');
            datxx.LatHem = datxx.LatHem{get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_4']),'value')};
            datxx.LongDeg = get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_5']),'string');
            datxx.LongMin = get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_6']),'string');
            datxx.LongHem = get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_7']),'string');
            datxx.LongHem = datxx.LongHem{get(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k) '_7']),'value')};
            %%% create and save string
            degchar = 'd'; % char(176) % 176 is Unicode number for degree symbol
            datar{k} = [datxx.LatDeg, degchar, datxx.LatMin, datxx.LatHem, ' ', datxx.LongDeg, degchar, datxx.LongMin, datxx.LongHem];
            %datxx.str = sprintf('%d%s%.4f%s %d%s%.4f%s',datxx.LatDeg, degchar, datxx.LatMin, datxx.LatHem, datxx.LongDeg, degchar, datxx.LongMin, datxx.LongHem);
            %%% save data
            %datar{k} = datxx.str;
    end
    set(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(k)]),'backgroundcolor','w')
end
if sum(badd)
    beep
    src.BackgroundColor=[1 0 0];
    for ab=find(badd)
        set(findobj(qqrc,'Tag',['xw_' num2str(dss) '_' num2str(ab)]),'backgroundcolor','r')
    end
else
 
    if addend%add end time
        if askadd
            timend=now;
            qxxxx=inputdlg('Last seen:','Last seen',1,{datestr(timend,dtStyle)});
            datar{addendk}=qxxxx{1};
        else
            datar{addendk}=datestr(now,dtStyle);
        end
    end
    %Counts
    if ~isempty(plcoul)
    for ii=find(plcoul(:,1)==dss)'%counts on that form
        Coul(ii)=datar{plcoul(ii,2)};
    end
    for ii=find(AddpreviousDone==dss)'%Running totals
        Coul(ii)=Coul(ii)+datar{plcoul(ii,2)-1};
    end
    Coul(find(RezeroStart==dss))=0;
    end
    savdat{dss}=[savdat{dss};datar];
    savedata;
    close(qqrc);
    
    hhf=length(findobj('tag',['xxxx' num2str(dss)]));
    if ~hhf
        src.BackgroundColor=[0.9400 0.9400 0.9400];
    end
end

function otherenter(obj,eventdata)
%allows input of other string with listbox
if strcmpi(obj.Style,'popupmenu')
    wwq=obj.String;
    wwqi=obj.Value;
    aq=[wwq{wwqi} '        '];
    if strcmpi(aq(1:5),'Other')
        obj.Style='edit';
        obj.String='';
    end
end

function fladd(obj,eventdata)
%adds data from pushbutton
global dtStyle
aft=findobj(obj.Parent,'tag',obj.Tag(1:(end-2)));
messs=[obj.String(1) datestr(now,dtStyle)];
if strcmp(obj.String(1),'F')
    fff=findobj('tag','flukeheading');
    if isempty(fff)
        wpo=get(findobj('tag','bigw'),'position');
        dq=figure('Menubar','none','toolbar','none','Name','Fluke headings:','tag','flukeheading','units','normalized','position',[wpo(1)+wpo(3)*0.2 wpo(2)+wpo(4)*0.2 wpo(3)*0.2 wpo(4)*0.25]);
        btn = uicontrol('Parent',dq,'Style','Pushbutton','units','normalized','Position',[0.3 0.05 0.4 0.15],...
               'String','DONE','Callback',{@fladdfluke,aft});
           uicontrol('Parent',dq,'style','text','units','normalized','Position',[0.05 0.87 0.9 0.10],...
               'String','Heading (Camera):','Fontsize',12,'foregroundcolor','b','tag','fffhht');
           uicontrol('Parent',dq,'style','edit','units','normalized','Position',[0.05 0.75 0.9 0.10],...
               'String',{[messs ': ']},'HorizontalAlignment','Left','Fontsize',12,'tag','fffhh');
    else
        qqn=length(findobj('tag','fffhh'));
        uicontrol('Parent',findobj('tag','flukeheading'),'style','edit','units','normalized','Position',[0.05 0.75-0.12*qqn 0.9 0.10],...
               'String',{[messs ': ']},'HorizontalAlignment','Left','Fontsize',12,'tag','fffhh');
    end
else
    set(aft,'string',[aft.String messs ' ']);
end

function fladdfluke(obj,eventdata,aft)
%Adds flukeheading data
qq=findobj('tag','fffhh');
messs=[];for j=length(qq):-1:1;messs=[messs deblank(qq(j).String{1}) ' '];end
set(aft,'string',[aft.String messs ' ']);
fff=findobj('tag','flukeheading');
delete(fff)


%%% Wilfried's functions
function GPSButton(obj,eventdata)
% Callback for "Update" button.
% Fetches GPS coordinates and prints them onscreen.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% get handles for complementing editboxes/popupmenus
baseTag = obj.Tag(1:(end-2));
aft = struct();
aft.LatDeg=findobj(obj.Parent,'Tag',[baseTag,'_2']); 
aft.LatMin=findobj(obj.Parent,'Tag',[baseTag,'_3']); 
aft.LatHem=findobj(obj.Parent,'Tag',[baseTag,'_4']); 
aft.LongDeg=findobj(obj.Parent,'Tag',[baseTag,'_5']); 
aft.LongMin=findobj(obj.Parent,'Tag',[baseTag,'_6']); 
aft.LongHem=findobj(obj.Parent,'Tag',[baseTag,'_7']); 
%%% create waitbar (just to signify something's happening - bar won't actually fill)
hWait = waitbar(0,'Getting GPS coordinates...');
%%% get GPS coordinates
[lat_deg,lat_min,lat_hem,long_deg,long_min,long_hem,failmsg] = getGPSCoords();
close(hWait)
if isempty(failmsg)
    %%% set uictrl strings/values
    aft.LatDeg.String = num2str(lat_deg);
    aft.LatMin.String = num2str(lat_min);
    aft.LatHem.Value = find(ismember(aft.LatHem.String,lat_hem));
    aft.LongDeg.String = num2str(long_deg);
    aft.LongMin.String = num2str(long_min);
    aft.LongHem.Value = find(ismember(aft.LongHem.String,long_hem));
else
    %%% GPS reading failed
    warndlg(failmsg,'GPS Failure')
end

function [lat_deg,lat_min,lat_hem,long_deg,long_min,long_hem,failmsg] = getGPSCoords()
% Joy's code for reading NMEA strings from bluetooth GPS unit 
% (adapted by Wilfried)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% initalize output
lat_deg = [];
lat_min = [];
lat_hem = '';
long_deg = [];
long_min = [];
long_hem = '';
failmsg = '';
% try reading GPS coordinates
try
    % create a serial port object to connect to gps
    gps = instrfind('Type', 'serial', 'Port', 'COM4');
    % create the serial port object if it does not exist, otherwise use the object that was found
    if isempty(gps)
        gps = serial('COM4');
    else
        fclose(gps);
    end
    % settings
    gps.BaudRate = 4800;
    gps.DataBits = 8;
    gps.StopBits = 1;
    gps.Terminator = 'CR/LF';
    % connect to gps
    fopen(gps);
    k = 0;
    loopcount = 0;
        gps = gps(1);
    while k == 0
        gpsdata = fgetl(gps); % read one line of data
        fields = textscan(gpsdata,'%s','delimiter',','); % extract data fields
        fields = fields{1};
        if (strcmp(fields{1}, '$GPGGA')) % if GPGGA string exists, check fix quality
            k = str2double(fields{7}); 
            if k > 0 % if fix quality is > 0, extract time, lat, lon from GPGGA string
                %gps_time = fields{2}(1:6); % time is HHMMSS
                lat_deg = str2double(fields{3}(1:2));
                lat_min = str2double(fields{3}(3:end));
                lat_hem = fields{4};
                long_deg = str2double(fields{5}(1:3));
                long_min = str2double(fields{5}(4:end));
                long_hem = fields{6};
            end
        end
        if loopcount >=10 % after 10 attempts, stop and show warning
            error('NMEA string not found or no gps fix')
        end
        loopcount = loopcount + 1;
    end
    % close connection to gps
    fclose(gps);
catch ME % error handling in case GPS coordinate extraction failed for whatever reason
    failmsg = sprintf('Failed to obtain GPS coordinates.\n\n%s',ME.message);
end



