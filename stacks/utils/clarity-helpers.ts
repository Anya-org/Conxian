/**
 * Clarity Value Parsing Utilities
 * Handles various Clarity value formats returned by simnet and contracts
 */

/**
 * Extracts uint value from Clarity value objects
 * Handles multiple formats:
 * - {type:'uint', value:'200'} - direct uint result
 * - {type:'err', value:{type:'uint', value:'307'}} - error with uint value
 * - 'u123' - string with u prefix
 * - 123 - raw number
 * - nested value objects
 */
export const getUintValue = (cv: any): number => {
  if (!cv && cv !== 0) return NaN;
  
  // Direct uint type
  if (cv.type === 'uint') {
    return parseInt(String(cv.value).replace(/^u/, ''), 10);
  }
  
  // String with u prefix or raw number string
  if (typeof cv === 'string') {
    return parseInt(cv.replace(/^u/, ''), 10);
  }
  
  // Raw number
  if (typeof cv === 'number') return cv;
  
  // Nested value (e.g., error responses)
  if (cv.value) {
    return getUintValue(cv.value);
  }
  
  // Fallback: extract from JSON representation
  const match = /u(\d+)/.exec(JSON.stringify(cv));
  return match ? parseInt(match[1], 10) : NaN;
};

/**
 * Extracts boolean value from Clarity value objects
 */
export const getBoolValue = (cv: any): boolean => {
  if (cv?.type === 'bool') return cv.value === true || cv.value === 'true';
  if (typeof cv === 'boolean') return cv;
  if (cv?.value !== undefined) return getBoolValue(cv.value);
  return false;
};

/**
 * Extracts principal value from Clarity value objects
 */
export const getPrincipalValue = (cv: any): string => {
  if (cv?.type === 'principal') return cv.value;
  if (typeof cv === 'string' && cv.includes('.')) return cv;
  if (cv?.value) return getPrincipalValue(cv.value);
  return '';
};

/**
 * Safely extracts value from Clarity response/result objects
 * Handles ok/err response wrappers
 */
export const unwrapResult = (result: any): any => {
  if (result?.type === 'ok') return result.value;
  if (result?.type === 'err') throw new Error(`Contract error: ${JSON.stringify(result.value)}`);
  return result;
};
