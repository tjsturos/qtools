package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/iden3/go-iden3-crypto/poseidon"
)

func main() {
	peerID := flag.String("peer-id", "", "Peer ID to convert to account address")
	flag.Parse()

	if *peerID == "" {
		// If peer ID is not provided, try to get it from qtools
		output, err := exec.Command("qtools", "peer-id").Output()
		if err != nil {
			fmt.Println("Error: Failed to get peer ID from qtools")
			flag.Usage()
			os.Exit(1)
		}

		// Trim any whitespace from the output
		peerIDFromQtools := strings.TrimSpace(string(output))

		if peerIDFromQtools == "Peer ID is not" {
			fmt.Println("Error: Peer ID is not available from qtools")
			flag.Usage()
			os.Exit(1)
		}

		// Use the peer ID from qtools
		*peerID = peerIDFromQtools
		fmt.Printf("Using peer ID from qtools: %s\n", *peerID)
		fmt.Println("Error: --peer-id is required")
		flag.Usage()
		os.Exit(1)
	}

	addr, err := poseidon.HashBytes([]byte(*peerID))
	if err != nil {
		fmt.Printf("Error hashing peer ID: %v\n", err)
		os.Exit(1)
	}

	accountAddress := "0x" + hex.EncodeToString(addr.FillBytes(make([]byte, 32)))

	fmt.Printf("Account address for peer ID %s: %s\n", *peerID, accountAddress)
}
