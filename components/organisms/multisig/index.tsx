import React, { useState, useEffect } from "react";
import { Card } from "../../atoms";
import * as multisigContract from "multisig";

// import styles from "./style.module.css";

const MultiSig = () => {
  const [from, setFrom] = useState("");
  const [token, setToken] = useState("");
  const [amount, setAmount] = useState("");
  const [claimants, setClaimants] = useState("");
  const [timeBound, setTimeBound] = useState("");
  const [claimant, setClaimant] = useState("");
  const [tokenAddress, setTokenAddress] = useState("");
  const [balance, setBalance] = useState("");

  const handleDeposit = async () => {
    try {
      const depositResult = await multisigContract.deposit({
        from,
        token,
        amount: BigInt(amount),
        claimants: claimants.split(",").map((addr) => addr.trim()),
        time_bound: {
          kind: { tag: "Before", values: void 0 },
          timestamp: BigInt(timeBound),
        },
      });
      console.log("Deposit Result:", depositResult);
    } catch (error) {
      console.error("Error during deposit:", error);
    }
  };

  const handleClaim = async () => {
    try {
      const claimResult = await multisigContract.claim({ claimant });
      console.log("Claim Result:", claimResult);
    } catch (error) {
      console.error("Error during claim:", error);
    }
  };

  const handleGetBalance = async () => {
    try {
      const balanceResult = await multisigContract.getBalance({
        token_address: tokenAddress,
      });
      let balance = Number(balanceResult) / 10 ** 7;
      setBalance(balance.toString());
      console.log("Balance Result:", balance.toString());
    } catch (error) {
      console.error("Error during balance:", error);
    }
  };

  return (
    <div>
      <h2>Deposit</h2>
      <input
        placeholder="From Address"
        value={from}
        onChange={(e) => setFrom(e.target.value)}
      />
      <input
        placeholder="Token Address"
        value={token}
        onChange={(e) => setToken(e.target.value)}
      />
      <input
        placeholder="Amount"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
      />
      <input
        placeholder="Claimants (comma-separated)"
        value={claimants}
        onChange={(e) => setClaimants(e.target.value)}
      />
      <input
        placeholder="Time Bound"
        value={timeBound}
        onChange={(e) => setTimeBound(e.target.value)}
      />
      <button onClick={handleDeposit}>Deposit</button>

      <h2>Claim</h2>
      <input
        placeholder="Claimant Address"
        value={claimant}
        onChange={(e) => setClaimant(e.target.value)}
      />
      <button onClick={handleClaim}>Claim</button>

      <h2>Get Balance</h2>
      <input
        placeholder="Token Address"
        value={tokenAddress}
        onChange={(e) => setTokenAddress(e.target.value)}
      />
      <button onClick={handleGetBalance}>Get Balance</button>
      <br />
      <strong>{balance}</strong>
    </div>
  );
};

export { MultiSig };
