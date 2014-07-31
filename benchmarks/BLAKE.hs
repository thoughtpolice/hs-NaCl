module BLAKE
       ( benchmarks -- :: IO [Benchmark]
       ) where
import           Criterion.Main
import           Crypto.Hash.BLAKE

import qualified Data.ByteString   as B

import           Util              ()

benchmarks :: IO [Benchmark]
benchmarks = return
  [ bench "blake256" $ nf blake256 (B.replicate 512 3)
  , bench "blake512" $ nf blake512 (B.replicate 512 3)
  ]
