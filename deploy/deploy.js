const { deploy1820 } = require('deploy-eip-1820')

const debug = require('debug')('ptv3:deploy.js')

const chainName = chainId => {
  switch (chainId) {
    case 1:
      return 'Mainnet'
    case 3:
      return 'Ropsten'
    case 4:
      return 'Rinkeby'
    case 5:
      return 'Goerli'
    case 42:
      return 'Kovan'
    case 31337:
      return 'BuidlerEVM'
    case 1337:
      return 'Mainnet Fork'
    default:
      return 'Unknown'
  }
}

/**
 * Get Aave LendingPoolAddressesProviderAddress
 * @param {Number} chainId
 * @return {String} LendingPoolAddressesProviderAddress
 */
const getLendingPoolAddressesProviderAddress = chainId => {
  switch (chainId) {
    case 1:
      return '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8'
    case 3:
      return '0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728'
    case 42:
      return '0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5'
    case 31337:
      return '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8'
    case 1337:
      return '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8'
  }
}

module.exports = async buidler => {
  const { getNamedAccounts, deployments, getChainId, ethers } = buidler
  const { deploy } = deployments

  const harnessDisabled = !!process.env.DISABLE_HARNESS

  let {
    deployer,
    rng,
    trustedForwarder,
    adminAccount,
    comptroller,
    reserve
  } = await getNamedAccounts()
  const chainId = parseInt(await getChainId(), 10)
  const isLocal = [1, 3, 4, 42].indexOf(chainId) == -1
  // 31337 is unit testing, 1337 is for coverage
  const isTestEnvironment = chainId === 31337 || chainId === 1337
  const signer = await ethers.provider.getSigner(deployer)

  debug('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  debug('PoolTogether Pool Contracts - Deploy Script')
  debug('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  const locus = isLocal ? 'local' : 'remote'
  debug(`  Deploying to Network: ${chainName(chainId)} (${locus})`)

  const lendingPoolAddressesProviderAddress = getLendingPoolAddressesProviderAddress(chainId)

  if (!adminAccount) {
    debug('  Using deployer as adminAccount;')
    adminAccount = signer._address
  }
  debug('\n  adminAccount:  ', adminAccount)

  await deploy1820(signer)

  if (isLocal) {
    debug('\n  Deploying TrustedForwarder...')
    const deployResult = await deploy('TrustedForwarder', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    trustedForwarder = deployResult.address

    debug('\n  Deploying RNGService...')
    const rngServiceMockResult = await deploy('RNGServiceMock', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    rng = rngServiceMockResult.address

    debug('\n  Deploying Dai...')
    const daiResult = await deploy('Dai', {
      args: ['DAI Test Token', 'DAI'],
      contract: 'ERC20Mintable',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    debug('\n  Deploying cDai...')
    // should be about 20% APR
    let supplyRate = '8888888888888'
    await deploy('cDai', {
      args: [daiResult.address, supplyRate],
      contract: 'CTokenMock',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    await deploy('yDai', {
      args: [daiResult.address],
      contract: 'yVaultMock',
      from: deployer,
      skipIfAlreadyDeployed: true
    })

    // Display Contract Addresses
    debug('\n  Local Contract Deployments;\n')
    debug('  - TrustedForwarder: ', trustedForwarder)
    debug('  - RNGService:       ', rng)
    debug('  - Dai:              ', daiResult.address)
  }

  let comptrollerAddress = comptroller
  // if not set by named config
  if (!comptrollerAddress) {
    const contract = isTestEnvironment ? 'ComptrollerHarness' : 'Comptroller'
    const comptrollerResult = await deploy('Comptroller', {
      contract,
      from: deployer,
      skipIfAlreadyDeployed: true
    })
    comptrollerAddress = comptrollerResult.address
    const comptrollerContract = await buidler.ethers.getContractAt(
      'Comptroller',
      comptrollerResult.address,
      signer
    )
    if (adminAccount !== deployer) {
      await comptrollerContract.transferOwnership(adminAccount)
    }
  }

  let reserveAddress = reserve
  // if not set by named config
  const reserveResult = await deploy("Reserve", {
    from: deployer,
    skipIfAlreadyDeployed: true
  })
  const reserveContract = await buidler.ethers.getContractAt(
    "Reserve",
    reserveResult.address,
    signer
  )
  if (adminAccount !== deployer) {
    await reserveContract.transferOwnership(adminAccount)
  }

  const reserveRegistryResult = await deploy("ReserveRegistry", {
    contract: 'Registry',
    from: deployer,
    skipIfAlreadyDeployed: true
  })
  const reserveRegistryContract = await buidler.ethers.getContractAt(
    "Registry",
    reserveRegistryResult.address,
    signer
  )
  if (await reserveRegistryContract.lookup() != reserveResult.address) {
    await reserveRegistryContract.register(reserveResult.address)
  }
  if (adminAccount !== deployer) {
    await reserveRegistryContract.transferOwnership(adminAccount)
  }

  let permitAndDepositDaiResult
  debug("\n  Deploying PermitAndDepositDai...")
  permitAndDepositDaiResult = await deploy("PermitAndDepositDai", {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying AavePrizePoolProxyFactory...')
  let aavePrizePoolProxyFactoryResult
  if (isTestEnvironment && !harnessDisabled) {
    aavePrizePoolProxyFactoryResult = await deploy('AavePrizePoolProxyFactory', {
      contract: 'AavePrizePoolHarnessProxyFactory',
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  } else {
    aavePrizePoolProxyFactoryResult = await deploy('AavePrizePoolProxyFactory', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  }

  debug('\n  Deploying CompoundPrizePoolProxyFactory...')
  let compoundPrizePoolProxyFactoryResult
  if (isTestEnvironment && !harnessDisabled) {
    compoundPrizePoolProxyFactoryResult = await deploy('CompoundPrizePoolProxyFactory', {
      contract: 'CompoundPrizePoolHarnessProxyFactory',
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  } else {
    compoundPrizePoolProxyFactoryResult = await deploy('CompoundPrizePoolProxyFactory', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  }

  let yVaultPrizePoolProxyFactoryResult
  if (isTestEnvironment && !harnessDisabled) {
    yVaultPrizePoolProxyFactoryResult = await deploy('yVaultPrizePoolProxyFactory', {
      contract: 'yVaultPrizePoolHarnessProxyFactory',
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  } else {
    yVaultPrizePoolProxyFactoryResult = await deploy('yVaultPrizePoolProxyFactory', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  }

  debug('\n  Deploying ControlledTokenProxyFactory...')
  const controlledTokenProxyFactoryResult = await deploy('ControlledTokenProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying TicketProxyFactory...')
  const ticketProxyFactoryResult = await deploy('TicketProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying StakePrizePoolProxyFactory...')
  const stakePrizePoolProxyFactoryResult = await deploy('StakePrizePoolProxyFactory', {
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying TwoWinnersProxyFactory...')
  let twoWinnersProxyFactoryResult
  if (isTestEnvironment && !harnessDisabled) {
    twoWinnersProxyFactoryResult = await deploy('TwoWinnersHarnessProxyFactory', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  } else {
    twoWinnersProxyFactoryResult = await deploy('TwoWinnersProxyFactory', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  }

  debug('\n  Deploying TwoWinnersBuilder...')
  const twoWinnersBuilderResult = await deploy('TwoWinnersBuilder', {
    args: [twoWinnersProxyFactoryResult.address],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug("\n  Deploying ControlledTokenBuilder...")
  const controlledTokenBuilderResult = await deploy("ControlledTokenBuilder", {
    args: [
      trustedForwarder,
      controlledTokenProxyFactoryResult.address,
      ticketProxyFactoryResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug("\n  Deploying SingleRandomWinnerProxyFactory...")
  let singleRandomWinnerProxyFactoryResult
  if (isTestEnvironment && !harnessDisabled) {
    singleRandomWinnerProxyFactoryResult = await deploy('SingleRandomWinnerProxyFactory', {
      contract: 'SingleRandomWinnerHarnessProxyFactory',
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  } else {
    singleRandomWinnerProxyFactoryResult = await deploy('SingleRandomWinnerProxyFactory', {
      from: deployer,
      skipIfAlreadyDeployed: true
    })
  }

  debug('\n  Deploying SingleRandomWinnerBuilder...')
  const singleRandomWinnerBuilderResult = await deploy('SingleRandomWinnerBuilder', {
    args: [
      singleRandomWinnerProxyFactoryResult.address,
      trustedForwarder,
      controlledTokenProxyFactoryResult.address,
      ticketProxyFactoryResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying AavePrizePoolBuilder...')
  const aavePrizePoolBuilderResult = await deploy('AavePrizePoolBuilder', {
    args: [
      comptrollerAddress,
      trustedForwarder,
      aavePrizePoolProxyFactoryResult.address,
      singleRandomWinnerBuilderResult.address,
      lendingPoolAddressesProviderAddress
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying CompoundPrizePoolBuilder...')
  const compoundPrizePoolBuilderResult = await deploy('CompoundPrizePoolBuilder', {
    args: [
      reserveRegistryResult.address,
      trustedForwarder,
      compoundPrizePoolProxyFactoryResult.address,
      singleRandomWinnerBuilderResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying yVaultPrizePoolBuilder...')
  const yVaultPrizePoolBuilderResult = await deploy('yVaultPrizePoolBuilder', {
    args: [
      reserveRegistryResult.address,
      trustedForwarder,
      yVaultPrizePoolProxyFactoryResult.address,
      singleRandomWinnerBuilderResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  debug('\n  Deploying StakePrizePoolBuilder...')
  const stakePrizePoolBuilderResult = await deploy('StakePrizePoolBuilder', {
    args: [
      reserveRegistryResult.address,
      trustedForwarder,
      stakePrizePoolProxyFactoryResult.address,
      singleRandomWinnerBuilderResult.address
    ],
    from: deployer,
    skipIfAlreadyDeployed: true
  })

  // Display Contract Addresses
  debug("\n  Contract Deployments Complete!\n")
  debug("  - TicketProxyFactory:             ", ticketProxyFactoryResult.address)
  debug("  - Reserve:                        ", reserveAddress)
  debug("  - Comptroller:                    ", comptrollerAddress)
  debug("  - CompoundPrizePoolProxyFactory:  ", compoundPrizePoolProxyFactoryResult.address)
  debug("  - ControlledTokenProxyFactory:    ", controlledTokenProxyFactoryResult.address)
  debug("  - SingleRandomWinnerProxyFactory: ", singleRandomWinnerProxyFactoryResult.address)
  debug('  - TwoWinnersProxyFactory:         ', twoWinnersProxyFactoryResult.address)
  debug("  - ControlledTokenBuilder:         ", controlledTokenBuilderResult.address)
  debug("  - SingleRandomWinnerBuilder:      ", singleRandomWinnerBuilderResult.address)
  debug('  - TwoWinnersBuilderResult:        ', twoWinnersBuilderResult.address)
  debug('  - AavePrizePoolBuilder:           ', aavePrizePoolBuilderResult.address)
  debug("  - CompoundPrizePoolBuilder:       ", compoundPrizePoolBuilderResult.address)
  debug("  - yVaultPrizePoolBuilder:         ", yVaultPrizePoolBuilderResult.address)
  debug("  - StakePrizePoolBuilder:          ", stakePrizePoolBuilderResult.address)
  if (permitAndDepositDaiResult) {
    debug('  - PermitAndDepositDai:            ', permitAndDepositDaiResult.address)
  }

  debug('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}
