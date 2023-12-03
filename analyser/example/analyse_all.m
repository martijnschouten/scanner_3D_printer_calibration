clear all
close all

addpath('../')

Analyser = analyser;

tic
%Analyser.analyse_interlocked_differential('data/','multi_tool',1,[1,2,3,4,5],false,false)
%Analyser.analyse_interlocked_differential('data/','multi_tool',2,[1,2,3,4,5],false,false)
%Analyser.analyse_interlocked_differential('data/','multi_tool',3,[1,2,3,4,5],false,false)
%Analyser.analyse_interlocked_differential('data/','multi_tool',4,[1,2,3,4,5],false,false)

Analyser.analyse_interlocked_differential('data/','single_tool',1,[2,2,2,2,2],false,false)
%Analyser.analyse_interlocked_differential('data/','single_tool',2,[2,2,2,2,2],false,false)
%Analyser.analyse_interlocked_differential('data/','single_tool',3,[2,2,2,2,2],false,false)
%Analyser.analyse_interlocked_differential('data/','single_tool',4,[2,2,2,2,2],false,false)
toc