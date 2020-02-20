import 'core-js/stable'
import 'regenerator-runtime/runtime'
import Aragon, { events } from '@aragon/api'
import { first } from 'rxjs/operators'

const app = new Aragon()

app.store(
  async (state, { event }) => {
    const nextState = {
      ...state,
    }

    try {
      switch (event) {
        case 'Staked':
          return { ...nextState, earned: await getEarned() }
        case 'Withdrawn':
          return { ...nextState, earned: await getEarned() }
        case 'RewardPaid':
          return { ...nextState, earned: await getEarned() }
        case 'RewardAdded':
          return { ...nextState, earned: await getEarned() }
        case events.SYNC_STATUS_SYNCING:
          return { ...nextState, isSyncing: true }
        case events.SYNC_STATUS_SYNCED:
          return { ...nextState, isSyncing: false }
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
      count: 0,
      earned: await getEarned()
    }
  }
}

const getEarned = async () => {
  const address = (await app.accounts().pipe(first()).toPromise())[0]
  return parseInt(await app.call('earned', address).toPromise(), 10)
}
