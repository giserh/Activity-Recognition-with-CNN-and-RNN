---------------------------------------------------------------
--  Activity-Recognition-with-CNN-and-RNN
--  https://github.com/chihyaoma/Activity-Recognition-with-CNN-and-RNN
-- 
-- 
--  Train a CNN on flow map of UCF-101 dataset 
-- 
-- 
--  Contact: Chih-Yao Ma at <cyma@gatech.edu>
---------------------------------------------------------------
-- 
--  This code incorporates material from: 
--  https://github.com/facebook/fb.resnet.torch
--
--  Copyright (c) 2016, Facebook, Inc.
--  All rights reserved.
--
--  This source code is licensed under the BSD-style license found in the
--  LICENSE file in the root directory of this source tree. An additional grant
--  of patent rights can be found in the PATENTS file in the same directory.

-- modified by: 
-- Chih-Yao Ma at <cyma@gatech.edu>
-- Min-Hung (Steve) Chen at <cmhungsteve@gatech.edu>

-- Last updated: 06/06/2016

--
local M = { }

function M.parse(arg)
   local cmd = torch.CmdLine()
   cmd:text()
   cmd:text('Torch-7 ResNet Training script')
   cmd:text()
   cmd:text('Options:')
    ------------ General options --------------------
   cmd:option('-data',       '/home/chih-yao/Downloads/dataset/UCF-101/FlowMap-Brox-frame/', 'Path to dataset')
   cmd:option('-dataset',    'ucf101-flow-brox', 'Options: ucf101 | ucf101-flow | ucf101-flow-brox | imagenet | cifar10')
   cmd:option('-manualSeed', 0,          'Manually set RNG seed')
   cmd:option('-nGPU',       4,          'Number of GPUs to use by default')
   cmd:option('-backend',    'cudnn',    'Options: cudnn | cunn')
   cmd:option('-cudnn',      'fastest',  'Options: fastest | default | deterministic')
   cmd:option('-gen',        'gen',      'Path to save generated files')
   ------------- Data options ------------------------
   cmd:option('-nThreads',        10, 'number of data loading threads')
   cmd:option('-nStacking',       10, 'number of stacks of optical flow images')
   cmd:option('-nChannel',       2, 'number of channels in one image: 2 | 3')
   ------------- Training options --------------------
   cmd:option('-nEpochs',         0,       'Number of total epochs to run')
   cmd:option('-epochNumber',     1,       'Manual epoch number (useful on restarts)')
   cmd:option('-batchSize',       64,      'mini-batch size (1 = pure stochastic)')
   cmd:option('-testOnly',        'false', 'Run on validation set only')
   cmd:option('-tenCrop',         'false', 'Ten-crop testing')
   cmd:option('-resume',          'none',  'Path to directory containing checkpoint')
   --cmd:option('-resume',          '',  'Path to directory containing checkpoint')
   ---------- Optimization options ----------------------
   cmd:option('-LR',              1e-3,   'initial learning rate')
   cmd:option('-momentum',        0.9,   'momentum')
   cmd:option('-weightDecay',     1e-4,  'weight decay')
   ---------- Model options ----------------------------------
   cmd:option('-netType',      'preresnet', 'Options: resnet | preresnet | wide-resnet')
   cmd:option('-depth',        101,       'ResNet depth: 18 | 34 | 50 | 101 | ...', 'number')
   cmd:option('-shortcutType', '',       'Options: A | B | C')
   --cmd:option('-retrain',      'model_best.t7',   'Path to model to retrain with')
   cmd:option('-retrain',      'none',   'Path to model to retrain with')
   -- cmd:option('-optimState',   '',   'Path to an optimState to reload from')
   cmd:option('-optimState',   'none',   'Path to an optimState to reload from')
   ---------- Model options ----------------------------------
   cmd:option('-shareGradInput',  'true', 'Share gradInput tensors to reduce memory usage')
   cmd:option('-resetClassifier', 'true', 'Reset the fully connected layer for fine-tuning')
   --cmd:option('-resetClassifier', 'false', 'Reset the fully connected layer for fine-tuning')
   cmd:option('-nClasses',         101,      'Number of classes in the dataset')
   ---------- Wide ResNet options ----------------------------------
   -- cmd:option('-depth',         40,      'Depth of the Wide ResNet should be 6n+4')
   cmd:option('-widen_factor',  1,      'Widen factor of the Wide ResNet')
   cmd:option('-dropout',     0,      'probability for dropout layer of the Wide ResNet')
   cmd:text()

   local opt = cmd:parse(arg or {})

   opt.testOnly = opt.testOnly ~= 'false'
   opt.tenCrop = opt.tenCrop ~= 'false'
   opt.shareGradInput = opt.shareGradInput ~= 'false'
   opt.resetClassifier = opt.resetClassifier ~= 'false'

   if opt.dataset == 'ucf101' or opt.dataset == 'ucf101-flow' 
      or opt.dataset == 'ucf101-flow-brox' or opt.dataset == 'imagenet' then
      -- Handle the most common case of missing -data flag
      local trainDir = paths.concat(opt.data, 'train')
      if not paths.dirp(opt.data) then
         cmd:error('error: missing dataset directory')
      elseif not paths.dirp(trainDir) then
         cmd:error('error: dataset missing `train` directory: ' .. trainDir)
      end
      -- Default shortcutType=B and nEpochs=90
      opt.shortcutType = opt.shortcutType == '' and 'B' or opt.shortcutType
      opt.nEpochs = opt.nEpochs == 0 and 90 or opt.nEpochs
   elseif opt.dataset == 'cifar10' then
      -- Default shortcutType=A and nEpochs=164
      opt.shortcutType = opt.shortcutType == '' and 'A' or opt.shortcutType
      opt.nEpochs = opt.nEpochs == 0 and 164 or opt.nEpochs
   else
      cmd:error('unknown dataset: ' .. opt.dataset)
   end

   if opt.resetClassifier then
      if opt.nClasses == 0 then
         cmd:error('-nClasses required when resetClassifier is set')
      end
   end

   if opt.nStacking == 'false' then opt.nStacking = 1 end

   return opt
end

return M
