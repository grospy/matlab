function Q = mohsst5_experiment_pca()

%
% Process data
%

data = mohsst5_loaddata();

% Form the data matrix
Y = mohsst5_remove_land(data.observations);
[M,N] = size(Y);
Obs = ~isnan(Y);

% Remove the test set from training data
Itest = load(sprintf('/share/bayes/data/jaakko/mohsst5/ind20test.mat'));
Itest = mohsst5_remove_land(Itest.Itest);
Itrain = ~Itest & Obs;
Itest = Itest & Obs;
Ytest = Y;
Ytest(~Itest) = nan;
Y(~Itrain) = nan;



%
% PCA inference
%

% Filename for saving the results
folder = sprintf('/share/climate/jluttine/mohsst5/pca/%s', ...
                 datestr(now, 'yyyymmdd'));
mkdir(folder);
filename = sprintf('%s/results_mohsst5_pca_%s', ...
                   folder, ...
                   datestr(now,'yyyymmdd'));

% Number of components
D = 80;

% PCA module for X
X_module = factor_module_iid(D, N);

% ARD module for W
W_module = factor_module_ard(D, M);

% Isotropic noise (precisions weighted proportionally to grid size)
weights = mohsst5_weights();
weights = mohsst5_remove_land(weights);
weights = repmat(weights, [1, N]);
noise_module = noise_module_isotropic(M, N, 1e-3, 1e-3, ...
                                      'init', 10, ...
                                      'weights', weights);

% Run VB PCA
Q = vbfa(D, Y, W_module, X_module, noise_module, ...
         'maxiter', 500, ...
         'rotate', [5:5:100 100:50:500], ...
         'autosavefile', filename, ...
         'autosave', [1 5:10:2000]);

% Reconstruct
Yh = Q.W'*Q.X;

% Some performance measures
sum_Itrain = sum(Itrain(:))
sum_Itest = sum(Itest(:))
fprintf('Weighted training RMSE of the reconstruction: %f\n',  ...
        rmsew(Y(Itrain)-Yh(Itrain),weights(Itrain)));
fprintf('Weighted test RMSE of the reconstruction: %f\n',  ...
        rmsew(Ytest(Itest)-Yh(Itest),weights(Itest)));
% $$$ fprintf('STD of noisy predictions: %f\n', ...
% $$$         sqrt(mean(mean(Q.W.^2'*Q.CovX + Q.CovW'*Q.X.^2 + Q.CovW'*Q.CovX)) ...
% $$$              + mean(1./Q.Tau(:))));
% $$$ fprintf('Estimated noise STD: %f\n', Q.Tau(1).^(-0.5))

fprintf('Performance measure, weighted RMSE for the test set: %f\n', ...
        mohsst5_performance_rmsew(Yh, Itest));

% Save the results
save(filename, '-struct', 'Q');
