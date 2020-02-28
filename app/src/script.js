import 'core-js/stable'
import 'regenerator-runtime/runtime'
import Aragon, { events } from '@aragon/api'
import { first, mergeMap, map } from 'rxjs/operators'
import ERC20Abi from './abi/erc20-abi'
import TokenWrapperAbi from './abi/token-wrapper-interface-abi'

const app = new Aragon()

app.store(
  async (state, { event }) => {
    const nextState = {
      ...state,
    }

    try {
      switch (event) {
        case 'Staked':
          return { ...nextState,
            stablecoinClaimable: await getStablecoinClaimable(),
            sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
            sctBalance: await getSctBalance() }
        case 'Withdrawn':
          return { ...nextState,
            stablecoinClaimable: await getStablecoinClaimable(),
            sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
            sctBalance: await getSctBalance() }
        case 'RewardPaid':
          return { ...nextState,
            stablecoinClaimable: await getStablecoinClaimable(),
            userStablecoinBalance: await getUserStablecoinBalance(),
            appStablecoinBalance: await getAppStablecoinBalance()
            }
        case 'RewardAdded':
          return { ...nextState,
            stablecoinClaimable: await getStablecoinClaimable(),
            userStablecoinBalance: await getUserStablecoinBalance(),
            appStablecoinBalance: await getAppStablecoinBalance(),
            rewardRate: await getRewardRate() }
        case events.SYNC_STATUS_SYNCING:
          return { ...nextState, isSyncing: true }
        case events.SYNC_STATUS_SYNCED:
          return { ...nextState, isSyncing: false }
        case events.ACCOUNTS_TRIGGER:
          return { ...nextState,
            sctAddress: await getSctAddress(),
            stablecoinAddress: await getStablecoinAddress(),
            stablecoinClaimable: await getStablecoinClaimable(),
            sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
            userStablecoinBalance: await getUserStablecoinBalance(),
            appStablecoinBalance: await getAppStablecoinBalance(),
            sctBalance: await getSctBalance(),
            rewardRate: await getRewardRate() }
        default:
          return state
      }
    } catch (err) {
      console.log(err)
    }
  },
  {
    init: initializeState(),
  }
)

/***********************
 *                     *
 *   Event Handlers    *
 *                     *
 ***********************/

function initializeState() {
  return async cachedState => {

    let newState = { ...cachedState }

    try {
      newState = {
        ...cachedState,
        sctAddress: await getSctAddress(),
        stablecoinAddress: await getStablecoinAddress(),
        stablecoinClaimable: await getStablecoinClaimable(),
        sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
        userStablecoinBalance: await getUserStablecoinBalance(),
        appStablecoinBalance: await getAppStablecoinBalance(),
        sctBalance: await getSctBalance(),
        rewardRate: await getRewardRate()
      }
    } catch (error) {
      console.error("Init error: ", error)
    }

    return newState
  }
}

const currentAddress = async () => (await app.accounts().pipe(first()).toPromise())[0]

const appAddress = async () => (await app.currentApp().toPromise()).appAddress

const getStablecoinClaimable = async () => {
  return await app.call('earned', await currentAddress()).toPromise()
}

const sctTokenWrapper$ = () =>
  app.call('wrappedSct').pipe(
    map(sctTokenWrapperAddress => app.external(sctTokenWrapperAddress, TokenWrapperAbi)))

const getSctAddress = async () => {
  return await sctTokenWrapper$().pipe(
    mergeMap(sctTokenWrapper => sctTokenWrapper.depositedToken())
  ).toPromise()
}

const getStablecoinAddress = async () => {
  return await app.call('stablecoin').toPromise()
}

const getSctTokenWrapperBalance = async () => {
  const address = await currentAddress()
  return await sctTokenWrapper$().pipe(
    mergeMap(sctTokenWrapper => sctTokenWrapper.balanceOf(address))
  ).toPromise()
}

const getSctBalance = async () => {
  const userAddress = await currentAddress()
  const sctAddress = await getSctAddress()
  return await app.external(sctAddress, ERC20Abi)
    .balanceOf(userAddress)
    .toPromise()
}

const getUserStablecoinBalance = async () => {
  const address = await currentAddress()
  return await getStablecoinBalance(address)
}

const getAppStablecoinBalance = async () => {
  const address = await appAddress()
  return await getStablecoinBalance(address)
}

const getStablecoinBalance = async (address) => {
  return await app.call('stablecoin').pipe(
    map(stablecoinAddress => app.external(stablecoinAddress, ERC20Abi)),
    mergeMap(stablecoin => stablecoin.balanceOf(address))
  ).toPromise()
}

const getRewardRate = async () => {
  return await app.call('rewardRate').toPromise()
}


