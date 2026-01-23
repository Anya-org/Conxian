export type FeeRecommendation = {
  fastestFee: number;
  halfHourFee: number;
  hourFee: number;
};

export async function getRecommendedFees(baseUrl: string): Promise<FeeRecommendation> {
  const url = `${baseUrl}/v1/fees/recommended`;
  const res = await fetch(url);
  if (!res.ok) {
    return { fastestFee: 15, halfHourFee: 8, hourFee: 5 };
  }
  return await res.json();
}

