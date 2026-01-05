  it("allows admin to update proposal registry address", () => {
    const newRegistry = Cl.contractPrincipal(deployer, "new-registry");
    
    const update = simnet.callPublicFn(
      "proposal-engine",
      "set-proposal-registry",
      [newRegistry],
      deployer
    );
    
    expect(update.result).toBeOk(Cl.bool(true));
  });
