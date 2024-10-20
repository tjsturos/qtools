package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/iden3/go-iden3-crypto/poseidon"
	"github.com/mr-tron/base58/base58"
)

func main() {
	peerIdInput := flag.String("peer-id", "", "Peer ID to convert to account address")
	flag.Parse()

	if *peerIdInput == "" {
		// If no peer ID is provided, get it from the qtools peer-id command
		output, err := exec.Command("qtools", "peer-id").Output()
		if err != nil {
			fmt.Printf("Error executing qtools peer-id: %v\n", err)
			os.Exit(1)
		}
		*peerIdInput = strings.TrimSpace(string(output))

		if *peerIdInput == "" {
			fmt.Println("Error: No peer ID provided and unable to retrieve it from qtools")
			os.Exit(1)
		}
	}

	peerIDBytes, err := base58.Decode(*peerIdInput)
	if err != nil {
		fmt.Printf("Error decoding peer ID: %v\n", err)
		os.Exit(1)
	}
	addr, err := poseidon.HashBytes(peerIDBytes)
	if err != nil {
		fmt.Printf("Error hashing peer ID: %v\n", err)
		os.Exit(1)
	}

	addrBytes := addr.FillBytes(make([]byte, 32))

	accountAddress := "0x" + hex.EncodeToString(addrBytes)

	fmt.Println(accountAddress)
}
