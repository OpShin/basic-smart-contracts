{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE MultiParamTypeClasses #-}


module IfLovelacePaidMintingPolicy where

import qualified PlutusTx
import           PlutusTx.Prelude       hiding (Semigroup(..), unless)
import           Ledger                 hiding (mint, singleton)
import qualified Ledger.Typed.Scripts   as Scripts
import           Ledger.Value           as Value
import           Ledger.Ada             as Ada
import           Prelude                (Show)

{-# OPTIONS_GHC -fno-warn-unused-imports #-}

-- Contract parameter object
data ContractParam = ContractParam
    { addressToPay :: PaymentPubKeyHash
    , minLovelaceAmount :: Integer
    } deriving Show

-- Tell compiler the ContractParam is liftable
PlutusTx.makeLift ''ContractParam

-- a pragma for the mkPolicy to make it possible to use it as inlinable parameter in the compile function
{-# INLINABLE mkPolicy #-}

--          Parameter            Redeemer   Context         Result
mkPolicy :: ContractParam     -> ()      -> ScriptContext-> Bool
mkPolicy contractParam () ctx = traceIfFalse "Minimum required lovelace not paid to address" requiredAmountPaid
    where
        info :: TxInfo
        info = scriptContextTxInfo ctx 

        requiredAmountPaid :: Bool
        requiredAmountPaid = (valueOf payment adaSymbol adaToken) >= minLovelaceAmount contractParam

        payment :: Value
        payment = valuePaidTo info (unPaymentPubKeyHash $ addressToPay contractParam)

-- compile policy into Plutus script
policy :: ContractParam -> Scripts.MintingPolicy
policy contractParam = mkMintingPolicyScript $
    $$(PlutusTx.compile [|| Scripts.wrapMintingPolicy . mkPolicy ||])
    `PlutusTx.applyCode`
    PlutusTx.liftCode contractParam

-- get currency symbol for policy
curSymbol :: ContractParam -> CurrencySymbol
curSymbol = scriptCurrencySymbol . policy