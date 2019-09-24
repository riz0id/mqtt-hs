{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Main where

import           Control.Monad        (void)
import qualified Data.ByteString.Lazy as BL
import           Data.Maybe           (fromJust)
import qualified Data.Text.IO         as TIO
import           Network.MQTT.Client
import           Network.URI
import           Options.Applicative  (Parser, argument, execParser, fullDesc,
                                       help, helper, info, long, maybeReader,
                                       metavar, option, progDesc, showDefault,
                                       some, str, value, (<**>))
import           System.IO            (stdout)

data Options = Options {
  optUri      :: URI
  , optTopics :: [Topic]
  }

options :: Parser Options
options = Options
  <$> option (maybeReader parseURI) (long "mqtt-uri" <> showDefault <> value (fromJust $ parseURI "mqtt://localhost/#whatever") <> help "mqtt broker URI")
  <*> some (argument str (metavar "topics..."))

run :: Options -> IO ()
run Options{..} = do
  mc <- connectURI mqttConfig{_msgCB=SimpleCallback showme, _protocol=Protocol50,
                              _connProps=[PropReceiveMaximum 65535,
                                          PropTopicAliasMaximum 10,
                                          PropRequestResponseInformation 1,
                                          PropRequestProblemInformation 1]}
        optUri

  void $ subscribe mc [(t, subOptions) | t <- optTopics] mempty

  print =<< waitForClient mc

    where showme _ t m props = do
            TIO.putStr $ mconcat [t, " → "]
            BL.hPut stdout m
            putStrLn ""
            mapM_ (putStrLn . ("  " <>) . show) props

main :: IO ()
main = run =<< execParser opts

  where opts = info (options <**> helper)
          ( fullDesc <> progDesc "Watch stuff.")
