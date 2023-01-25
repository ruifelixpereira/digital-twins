/**
 * @summary Simple example to update a property value
 */

const { DefaultAzureCredential } = require("@azure/identity");
const { DigitalTwinsClient } = require("@azure/digital-twins-core");
const { inspect } = require("util");
const { v4 } = require("uuid");
const { setIntervalAsync, clearIntervalAsync } = require('set-interval-async');

let SmartInterval = require("smartinterval");

// Load environment
require('dotenv').config();

const LIVE_PUSH_FREQUENCY = 10 * 10000;

function generateRandom(min = 0, max = 100) {
  // find diff
  let difference = max - min;

  // generate random number 
  let rand = Math.random();

  // multiply with difference 
  rand = Math.floor(rand * difference);
  //rand = rand * difference;

  // add with min value 
  rand = rand + min;

  return rand;
}

async function main() {
  // AZURE_DIGITALTWINS_URL: The URL to your Azure Digital Twins instance
  const url = process.env.AZURE_DIGITALTWINS_URL;
  if (url === undefined) {
    throw new Error("Required environment variable AZURE_DIGITALTWINS_URL is not set.");
  }

  // DefaultAzureCredential is provided by @azure/identity. It supports
  // different authentication mechanisms and determines the appropriate
  // credential type based of the environment it is executing in. See
  // https://www.npmjs.com/package/@azure/identity for more information on
  // authenticating with DefaultAzureCredential or other implementations of
  // TokenCredential.
  const credential = new DefaultAzureCredential();
  const serviceClient = new DigitalTwinsClient(url, credential);

  // Get digital twin
  const digitalTwinId = process.env.DIGITAL_TWIN_ID; //Digital twin ID must exist in your Azure Digital Twins instance
  const getTwin = await serviceClient.getDigitalTwin(digitalTwinId);
  //console.log(`Get Digital Twin:`);
  //console.log(inspect(getTwin));

  // Initialize the interval by new-ing the SmartInterval constructor
  // It accepts 2 arguments:
  // - An async function to be executed (job)
  // - The time to wait between cycles (delay)
  let dataFetcher = new SmartInterval(
    async () => {
      //console.log('Pushing live data: ', new Date())

      // Update digital twin
      const twinPatch = {
        op: "add",
        path: "/humidity",
        value: generateRandom(30, 48)
      };

      const updatedTwin = await serviceClient.updateDigitalTwin(digitalTwinId, [twinPatch]);
      console.log(`Updated Digital Twin:`);
      console.log(inspect(updatedTwin));
    },
    LIVE_PUSH_FREQUENCY
  );

  // You can start it
  dataFetcher.start();
}

main().catch((err) => {
  console.log("error code: ", err.code);
  console.log("error message: ", err.message);
  console.log("error stack: ", err.stack);
});
