-- | This module provides the proxy transformer equivalent of 'ReaderT'.

{-# LANGUAGE FlexibleContexts, KindSignatures #-}

module Control.Proxy.Trans.Reader (
    -- * ReaderP
    ReaderP(..),
    withReaderT,
    -- * Reader operations
    ask,
    local,
    asks,
    ) where

import Control.Applicative (Applicative(pure, (<*>)), Alternative(empty, (<|>)))
import Control.Monad (liftM, ap, MonadPlus(mzero, mplus))
import Control.Monad.IO.Class (MonadIO(liftIO))
import Control.Monad.Trans.Class (MonadTrans(lift))
import Control.MFunctor (MFunctor(mapT))
import Control.Proxy.Class (
    Channel(idT    , (>->)), 
    Request(request, (\>\)), 
    Respond(respond, (/>/)))
import Control.Proxy.Trans (ProxyTrans(liftP))

-- | The 'Reader' proxy transformer
newtype ReaderP i p a' a b' b (m :: * -> *) r
  = ReaderP { runReaderP :: i -> p a' a b' b m r }

instance (Monad (p a' a b' b m)) => Functor (ReaderP i p a' a b' b m) where
    fmap = liftM

instance (Monad (p a' a b' b m)) => Applicative (ReaderP i p a' a b' b m) where
    pure  = return
    (<*>) = ap

instance (Monad (p a' a b' b m)) => Monad (ReaderP i p a' a b' b m) where
    return a = ReaderP $ \_ -> return a
    m >>= f = ReaderP $ \i -> do
        a <- runReaderP m i
        runReaderP (f a) i

instance (MonadPlus (p a' a b' b m))
 => Alternative (ReaderP i p a' a b' b m) where
    empty = mzero
    (<|>) = mplus

instance (MonadPlus (p a' a b' b m))
 => MonadPlus (ReaderP i p a' a b' b m) where
    mzero = ReaderP $ \_ -> mzero
    mplus m1 m2 = ReaderP $ \i -> mplus (runReaderP m1 i) (runReaderP m2 i)

instance (MonadTrans (p a' a b' b)) => MonadTrans (ReaderP i p a' a b' b) where
    lift m = ReaderP $ \_ -> lift m

instance (MonadIO (p a' a b' b m)) => MonadIO (ReaderP i p a' a b' b m) where
    liftIO m = ReaderP $ \_ -> liftIO m

instance (MFunctor (p a' a b' b)) => MFunctor (ReaderP i p a' a b' b) where
    mapT nat = ReaderP . fmap (mapT nat) . runReaderP

instance (Channel p) => Channel (ReaderP i p) where
    idT a = ReaderP $ \_ -> idT a
    (p1 >-> p2) a = ReaderP $ \i ->
        ((`runReaderP` i) . p1 >-> (`runReaderP` i) . p2) a

instance (Request p) => Request (ReaderP i p) where
    request a = ReaderP $ \_ -> request a
    (p1 \>\ p2) a = ReaderP $ \i ->
        ((`runReaderP` i) . p1 \>\ (`runReaderP` i) . p2) a

instance (Respond p) => Respond (ReaderP i p) where
    respond a = ReaderP $ \_ -> respond a
    (p1 />/ p2) a = ReaderP $ \i ->
        ((`runReaderP` i) . p1 />/ (`runReaderP` i) . p2) a

instance ProxyTrans (ReaderP i) where
    liftP m = ReaderP $ \_ -> m

-- | Fetch the value of the environment
ask :: (Monad (p a' a b' b m)) => ReaderP i p a' a b' b m i
ask = ReaderP return

-- | Retrieve a function of the current environment
asks :: (Monad (p a' a b' b m)) => (i -> r) -> ReaderP i p a' a b' b m r
asks f = ReaderP (return . f)

{-| Execute a computation in a modified environment (a more general version of
    'local') -}
withReaderT
 :: (Monad (p a' a b' b m))
 => (j -> i) -> ReaderP i p a' a b' b m r -> ReaderP j p a' a b' b m r
withReaderT f r = ReaderP $ runReaderP r . f

{-| Execute a computation in a modified environment (a specialization of
    'withReaderT' -}
local
 :: (Monad (p a' a b' b m))
 => (i -> i) -> ReaderP i p a' a b' b m r -> ReaderP i p a' a b' b m r
local = withReaderT