import { config } from '@onflow/fcl'

config({
  'app.detail.title': 'YOLO — Coin Toss on Flow',
  'app.detail.icon': 'https://placekitten.com/g/200/200',
  'accessNode.api': 'https://rest-testnet.onflow.org',
  'flow.network': 'testnet',
  'discovery.wallet': 'https://fcl-discovery.onflow.org/testnet/authn',
  '0xCoinFlip': '0xeb24b78eb89a2076',
  '0xFungibleToken': '0x9a0766d93b6608b7',
  '0xFlowToken': '0x7e60df042a9c0868',
})
