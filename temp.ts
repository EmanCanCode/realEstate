
let private_key: any;
class Class {
    web3: any;
    contract: any;
    contract_address: any;
    owner: any;
    sendNFT(to: string, id: number): Promise<string> {
        return new Promise(async (resolve, reject) => {
            const tx = {
                from: this.owner,
                to: this.contract_address,
                gas: 50000,
                data: this.contract.methods.transferFrom(this.owner, to, id).encodeABI()
            };

            const signature = await this.web3.eth.accounts.signTransaction(tx, private_key);

            this.web3.eth.sendSignedTransaction(signature.rawTransaction).on(
                "receipt", async () => {
                    const event = await this.findEvent("Transfer", { from: this.contract_address, to });
                    resolve(JSON.stringify(event));
                }
            ).on(
                'error', async (reason: any) => {
                    reject(JSON.stringify(reason));
                }
            );
        });
    }

    async findEvent(eventName: string, filter: any) {
        // Get all events of the specified event name
        const events = await this.contract.getPastEvents(eventName, { fromBlock: 0, toBlock: 'latest' });
      
        // Find the first event that matches the filter
        const event = events.find(event => {
          // Check if the event matches the filter
          if (event.returnValues && Object.entries(filter).every(([key, value]) => event.returnValues[key] === value)) {
            return true;
          }
          return false;
        });
      
        return event;
    }
}