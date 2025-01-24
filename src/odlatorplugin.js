
/**
@version        0.4.7
@description    mainentry for odlator da plugin 

*/
function processDocument(templateDocument, dataset) {
    return new Promise((resolve, reject) => {
        // Save odlatormodule in closure to ensure scope isn't lost
        let odlatorModule;

        require(['odlatormodule'],
            function (module) {
                odlatorModule = module;
                try {
                    const odtDocument = new odlatorModule.ODLATORProcessor(templateDocument, apex.debug);
                    return odtDocument.process(dataset)
                        .then(resolve)
                        .catch(reject);
                } catch (error) {
                    reject(error);

                }
            },
            function (error) {
                reject(new Error(`Failed to load odlatormodule: ${error}`));
            }
        );
    });
}

function base64toBlob(base64String, mimeType) {
    // Input validation
    if (!base64String || typeof base64String !== 'string') {
        throw new Error('Invalid base64 string');
    }
    if (!mimeType || typeof mimeType !== 'string') {
        throw new Error('Invalid MIME type');
    }

    try {
        const byteCharacters = atob(base64String);
        const byteArray = new Uint8Array(byteCharacters.length);

        for (let i = 0; i < byteCharacters.length; i++) {
            byteArray[i] = byteCharacters.charCodeAt(i);
        }

        return new Blob([byteArray], { type: mimeType });
    } catch (e) {
        if (typeof window.BlobBuilder !== "undefined") {
            const bb = new BlobBuilder();
            bb.append(byteArray.buffer);
            return bb.getBlob(mimeType);
        }
        throw new Error(`Failed to create Blob: ${e.message}`);
    }
}

/**
 * Recursively converts all object keys to lowercase
 * @param {*} obj - The object to convert
 * @returns {*} The converted object
 */
function convertKeysToLowerCase(obj) {
    if (typeof obj !== 'object' || obj === null) {
        return obj;
    }

    if (Array.isArray(obj)) {
        return obj.map(convertKeysToLowerCase);
    }

    const newObj = {};
    for (const key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
            newObj[key.toLowerCase()] = convertKeysToLowerCase(obj[key]);
        }
    }
    return newObj;
}

/**
 * Main entry point 
 */

function parseJsonData(dataclob) {
    try {
        // Get the first object from data array
        const firstParse = dataclob.data[0];
        
        // If it's a direct string, parse it
        if (typeof firstParse === 'string') {
            return JSON.parse(firstParse);
        }

        // If it's an object, find the first value that's a JSON string and parse it
        if (typeof firstParse === 'object') {
            // Get the first value in the object that can be parsed as JSON
            for (let key in firstParse) {
                try {
                    const value = firstParse[key];
                    if (typeof value === 'string') {
                        return JSON.parse(value);
                    }
                } catch (e) {
                    continue; // Try next key if this one fails
                }
            }
        }

        return firstParse;

    } catch (error) {
        try {
            return JSON.parse(dataclob);
        } catch (error) {
            console.error('Failed to parse JSON:', error);
            return {};
        }
    }
}


async function mainEntry() {
    "use strict";

    const spinner = apex.util.showSpinner();
    const target = document.getElementsByName('body');
    const da = this;

    try {
        //apex.event.trigger(target, 'event', 'starting');
        apex.debug.info('starting ');
        // Get template and data
        const result = await apex.server.plugin(
            da.action.ajaxIdentifier,
            { pageItems: da.action.attribute03 }
        );
        //TODO : simplify apex.server.plugin 

        apex.debug.info('template received');
        //apex.event.trigger(target, 'event', 'template received');

        // Process the data
        const { mimetype, base64 } = result.template;
        //let dataset;
        
        let dataset = convertKeysToLowerCase(parseJsonData(result.data.value));

        // apex.debug.info('dataset converted parsed',JSON.parse(dataset));
        // apex.event.trigger(target, 'event', 'data converted');

        // Process and save document
        const templateBlob = base64toBlob(base64, mimetype);
        const processedDoc = await processDocument(templateBlob, dataset);

        saveAs(processedDoc, da.action.attribute01);

        //apex.event.trigger(target, 'event', 'end');

    } catch (error) {
        console.error('Processing failed:', error);
        apex.debug.error('Document processing error:', error);
        apex.event.trigger(target, 'event', {
            type: 'error',
            phase: error.phase || 'unknown',
            message: error.message
        });
    } finally {
        spinner.remove();
    }
}