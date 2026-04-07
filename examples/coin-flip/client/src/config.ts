import { config } from '@onflow/fcl'

config({
  'app.detail.title': 'YOLO — Coin Toss on Flow',
  'app.detail.icon': 'https://placekitten.com/g/200/200',
  'accessNode.api': 'http://localhost:8888',
  'flow.network': 'emulator',
  'discovery.wallet': 'http://localhost:8701/fcl/authn',
  '0xCoinFlip': '0xf8d6e0586b0a20c7',
  '0xFungibleToken': '0xee82856bf20e2aa6',
  '0xFlowToken': '0x0ae53cb6e3f42a79',
})
