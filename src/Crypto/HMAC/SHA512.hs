{-# LANGUAGE EmptyDataDecls           #-}
{-# LANGUAGE ForeignFunctionInterface #-}
-- |
-- Module      : Crypto.HMAC.SHA512
-- Copyright   : (c) Austin Seipp 2013
-- License     : BSD3
--
-- Maintainer  : aseipp@pobox.com
-- Stability   : experimental
-- Portability : portable
--
-- This module implements minimal bindings to HMAC-SHA-512-256,
-- i.e. the first 256 bits of HMAC-SHA-512. The underlying
-- implementation is the @ref@ code of @hmacsha512256@ from SUPERCOP,
-- and should be relatively fast.
--
-- This module is intended to be imported @qualified@ to avoid name
-- clashes with other cryptographic primitives, e.g.
--
-- > import qualified Crypto.HMAC.SHA512 as HMACSHA512
--
module Crypto.HMAC.SHA512
       ( -- Security model
         -- $securitymodel

         -- * Types
         HMACSHA512   -- :: *
       , Auth(..)     -- :: *

         -- * Key creation
       , randomKey    -- :: IO (SecretKey HMACSHA512)

         -- * Authentication
         -- ** Example usage
         -- $example
       , authenticate -- :: SecretKey HMACSHA512 -> ByteString -> Auth
       , verify       -- :: SecretKey HMACSHA512 -> Auth -> ByteString -> Bool
       ) where
import           Data.Word
import           Foreign.C.Types
import           Foreign.Ptr

import           System.IO.Unsafe         (unsafePerformIO)

import           Data.ByteString          (ByteString)
import           Data.ByteString.Internal (create)
import           Data.ByteString.Unsafe

import           Crypto.Key
import           System.Crypto.Random

-- $securitymodel
--
-- The @'authenticate'@ function, viewed as a function of the message
-- for a uniform random key, is designed to meet the standard notion
-- of unforgeability. This means that an attacker cannot find
-- authenticators for any messages not authenticated by the sender,
-- even if the attacker has adaptively influenced the messages
-- authenticated by the sender. For a formal definition see, e.g.,
-- Section 2.4 of Bellare, Kilian, and Rogaway, \"The security of the
-- cipher block chaining message authentication code,\" Journal of
-- Computer and System Sciences 61 (2000), 362–399;
-- <http://www-cse.ucsd.edu/~mihir/papers/cbc.html>.
--
-- NaCl does not make any promises regarding \"strong\"
-- unforgeability; perhaps one valid authenticator can be converted
-- into another valid authenticator for the same message. NaCl also
-- does not make any promises regarding \"truncated unforgeability.\"

-- $setup
-- >>> :set -XOverloadedStrings

-- | A phantom type for representing types related to SHA-512-256
-- HMACs.
data HMACSHA512

-- | Generate a random key for performing encryption.
--
-- Example usage:
--
-- >>> key <- randomKey
randomKey :: IO (SecretKey HMACSHA512)
randomKey = SecretKey `fmap` randombytes hmacsha512256KEYBYTES

-- | An authenticator.
newtype Auth = Auth { unAuth :: ByteString }
  deriving (Eq, Show, Ord)

-- | @'authenticate' k m@ authenticates a message @'m'@ using a
-- @'SecretKey'@ @k@ and returns the authenticator, @'Auth'@.
authenticate :: SecretKey HMACSHA512
             -- ^ Secret key
             -> ByteString
             -- ^ Message
             -> Auth
             -- ^ Authenticator
authenticate (SecretKey k) msg =
  Auth . unsafePerformIO . create hmacsha512256BYTES $ \out ->
    unsafeUseAsCStringLen msg $ \(cstr, clen) ->
      unsafeUseAsCString k $ \pk ->
        c_crypto_hmacsha512256 out cstr (fromIntegral clen) pk >> return ()
{-# INLINE authenticate #-}

-- | @'verify' k a m@ verifies @a@ is the correct authenticator of @m@
-- under a @'SecretKey'@ @k@.
verify :: SecretKey HMACSHA512
       -- ^ Secret key
       -> Auth
       -- ^ Authenticator returned via @'authenticate'@
       -> ByteString
       -- ^ Message
       -> Bool
       -- ^ Result: @'True'@ if verified, @'False'@ otherwise
verify (SecretKey k) (Auth auth) msg =
  unsafePerformIO . unsafeUseAsCString auth $ \pauth ->
    unsafeUseAsCStringLen msg $ \(cstr, clen) ->
      unsafeUseAsCString k $ \pk -> do
        b <- c_crypto_hmacsha512256_verify pauth cstr (fromIntegral clen) pk
        return (b == 0)
{-# INLINE verify #-}

-- $example
-- >>> key <- randomKey
-- >>> let a = authenticate key "Hello"
-- >>> verify key a "Hello"
-- True

--
-- FFI mac binding
--

hmacsha512256KEYBYTES :: Int
hmacsha512256KEYBYTES = 32

hmacsha512256BYTES :: Int
hmacsha512256BYTES = 32

foreign import ccall unsafe "sha512256_hmac"
  c_crypto_hmacsha512256 :: Ptr Word8 -> Ptr CChar -> CULLong ->
                          Ptr CChar -> IO Int

foreign import ccall unsafe "sha512256_hmac_verify"
  c_crypto_hmacsha512256_verify :: Ptr CChar -> Ptr CChar -> CULLong ->
                                 Ptr CChar -> IO Int
