// Import the IPFS HTTP client library
import { create } from 'ipfs-http-client';

// Connect to the local IPFS node
const ipfs = create({ url: 'http://localhost:5001' });

// async function uploadJsonToIpfs() {
//     // Define your JSON data
//     const jsonData = {
//         name: "293 Lafayette St PENTHOUSE 1, New York, NY 10012",
//         description: "Luxury NYC Penthouse",
//         image: "https://ipfs.io/ipfs/QmUsuRJyRUmeHzZxes5FRMkc4mjx35HbaTzHzzWoiRdT5G",
//         attributes: [
//             // Add your attributes here
//         ]
//     };

//     // Convert JSON object to string
//     const jsonStr = JSON.stringify(jsonData);

//     // Add the JSON data to IPFS
//     try {
//         const added = await ipfs.add(jsonStr);
//         const cid = added.cid.toString();
//         // Construct the full IPFS URL with the CID
//         const url = `https://ipfs.io/ipfs/${cid}`;
//         console.log(`Uploaded JSON to IPFS: ${url}`);
//         return url;
//     } catch (error) {
//         console.error('Error uploading JSON to IPFS:', error);
//         return null;
//     }
// }

// // Run the function
// uploadJsonToIpfs().then(url => console.log(url));


