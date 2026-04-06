import ChessGame from "ChessGame"
access(all) fun main(addr: Address): [UInt64] {
    return ChessGame.getActiveGamesForAddress(addr)
}
