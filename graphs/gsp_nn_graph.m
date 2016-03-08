function [ G ] = gsp_nn_graph(Xin, param)
%GSP_NN_GRAPH Create a nearest neighbors graph from a point cloud
%   Usage :  G = gsp_nn_graph( Xin );
%            G = gsp_nn_graph( Xin, param );
%
%   Input parameters:
%       Xin         : Input points
%       param       : Structure of optional parameters
%
%   Output parameters:
%       G           : Resulting graph
%
%   'gsp_nn_graph( Xin, param )' creates a graph from positional data. The points are 
%   connected to their neighbors (either belonging to the k nearest 
%   neighbors or to the epsilon-closest neighbors. 
%
%   Example:
%
%           P = gsp_pointcloud('bunny');
%           param.type = 'knn';
%           G = gsp_nn_graph(P, param);
%           gsp_plot_graph(G);
%
%   Additional parameters
%   ---------------------
%
%    param.type      : ['knn', 'radius']   the type of graph (default 'knn')
%    param.use_flann : [0, 1]              use the FLANN library
%    param.use_full  : [0, 1] - Compute the full distance matrix and then
%     sparsify it (default 0) 
%    param.center    : [0, 1]              center the data
%    param.rescale   : [0, 1]              rescale the data (in a 1-ball)
%    param.sigma     : float               the variance of the distance kernel
%    param.k         : int                 number of neighbors for knn
%    param.epsilon   : float               the radius for the range search
%    param.use_l1    : [0, 1]              use the l1 distance
%    param.symmetrize_type*: ['average','full'] symmetrization type (default 'full')
%
%   See also: gsp_pointcloud
%
%
%   Url: http://lts2research.epfl.ch/gsp/doc/graphs/gsp_nn_graph.php

% Copyright (C) 2013-2016 Nathanael Perraudin, Johan Paratte, David I Shuman.
% This file is part of GSPbox version 0.5.1
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

% If you use this toolbox please kindly cite
%     N. Perraudin, J. Paratte, D. Shuman, V. Kalofolias, P. Vandergheynst,
%     and D. K. Hammond. GSPBOX: A toolbox for signal processing on graphs.
%     ArXiv e-prints, Aug. 2014.
% http://arxiv.org/abs/1408.5781

% Author: Johan Paratte, Nathanael Perraudin
% Date: 16 June 2014
% Testing: test_rmse

    if nargin < 2
    % Define parameters
        param = {};
    end
    
    %Parameters
    if ~isfield(param, 'type'), param.type = 'knn'; end
    if ~isfield(param, 'use_flann'), param.use_flann = 0; end
    if ~isfield(param, 'center'), param.center = 0; end
    if ~isfield(param, 'rescale'), param.rescale = 0; end
    if ~isfield(param, 'k'), param.k = 10; end
    if ~isfield(param, 'epsilon'), param.epsilon = 0.01; end
    if ~isfield(param, 'use_l1'), param.use_l1 = 0; end
    if ~isfield(param, 'target_degree'), param.target_degree = 0; end;
    if ~isfield(param, 'symmetrize_type'), param.symmetrize_type = 'average'; end
    if ~isfield(param, 'light'); param.light = 0; end
    paramnn = param;
    paramnn.k = param.k +1;
    [indx, indy, dist, Xout, ~, epsilon] = gsp_nn_distanz(Xin',Xin',paramnn);
    Xout = transpose(Xout);
    switch param.type
        case 'knn'
            if param.use_l1
                if ~isfield(param, 'sigma'), param.sigma = mean(dist); end
            else
                if ~isfield(param, 'sigma'), param.sigma = mean(dist)^2; end
            end
        case 'radius'
            if param.use_l1
                if ~isfield(param, 'sigma'), param.sigma = epsilon/2; end
            else
                if ~isfield(param, 'sigma'), param.sigma = epsilon.^2/2; end
            end
        otherwise
            error('Unknown graph type')
    end
    
    n = size(Xin,1);
    
    if param.use_l1
        W = sparse(indx, indy, double(exp(-dist/param.sigma)), n, n);
    else
        W = sparse(indx, indy, double(exp(-dist.^2/param.sigma)), n, n);
    end
    
    % We need zero diagonal
    W(1:(n+1):end) = 0;     % W = W-diag(diag(W));
    
    % Computes the average degree when using the epsilon-based neighborhood
    if (strcmp(param.type,'radius'))
        text = sprintf('Average number of connection = %d', nnz(W)/size(W, 1));
        disp(text);
    end

    % Sanity check
    if size(W,1) ~= size(W,2), error('Weight matrix W is not square'); end
    
    % Symmetry checks
    %if issymmetric(W)
    if (norm(W - W', 'fro') == 0)
        disp('The matrix W is symmetric');
    else
         W = gsp_symmetrize(W,param.symmetrize_type);
    end
    
    %Fill in the graph structure
    G.N = n;
    G.W = W;
    G.coords = Xout;
    %G.limits=[-1e-4,1.01*max(x),-1e-4,1.01*max(y)];
    if param.use_l1
        G.type = 'nearest neighbors l1';
    else
        G.type = 'nearest neighbors';
    end
    %G.vertex_size=30;
    G.sigma = param.sigma;
    if param.light
        G = gsp_graph_lightweight_parameters(G);
    else
        G = gsp_graph_default_parameters(G);
    end
end


