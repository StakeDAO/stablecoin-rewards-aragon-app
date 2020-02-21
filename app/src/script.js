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
            earned: await getEarned(),
            sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
            stablecoinBalance: await getStablecoinBalance(),
            sctBalance: await getSctBalance() }
        case 'Withdrawn':
          return { ...nextState,
            earned: await getEarned(),
            sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
            stablecoinBalance: await getStablecoinBalance(),
            sctBalance: await getSctBalance() }
        case 'RewardPaid':
          return { ...nextState, earned: await getEarned() }
        case 'RewardAdded':
          return { ...nextState, earned: await getEarned() }
        case events.SYNC_STATUS_SYNCING:
          return { ...nextState, isSyncing: true }
        case events.SYNC_STATUS_SYNCED:
          return { ...nextState, isSyncing: false }
        case events.ACCOUNTS_TRIGGER:
          return { ...nextState,
            earned: await getEarned(),
            sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
            stablecoinBalance: await getStablecoinBalance(),
            sctBalance: await getSctBalance() }
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
    return {
      ...cachedState,
      sctAddress: await getSctAddress(),
      earned: await getEarned(),
      sctTokenWrapperBalance: await getSctTokenWrapperBalance(),
      stablecoinBalance: await getStablecoinBalance(),
      sctBalance: await getSctBalance()
    }
  }
}

const currentAddress = async () => (await app.accounts().pipe(first()).toPromise())[0]

const getEarned = async () => {
  return parseInt(await app.call('earned', await currentAddress()).toPromise(), 10)
}

const sctTokenWrapper$ = () =>
  app.call('wrappedSct').pipe(
    map(sctTokenWrapperAddress => app.external(sctTokenWrapperAddress, TokenWrapperAbi)))

const getSctAddress = async () => {
  return await sctTokenWrapper$().pipe(
    mergeMap(sctTokenWrapper => sctTokenWrapper.depositedToken())
  ).toPromise()
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

const getStablecoinBalance = async () => {
  const address = await currentAddress()
  return await app.call('stablecoin').pipe(
    map(stablecoinAddress => app.external(stablecoinAddress, ERC20Abi)),
    mergeMap(stablecoin => stablecoin.balanceOf(address))
  ).toPromise()
}
