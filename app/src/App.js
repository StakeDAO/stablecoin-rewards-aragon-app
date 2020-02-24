import React, { useState } from 'react'
import { useAragonApi } from '@aragon/api-react'
import {
  Box,
  Button,
  GU,
  Header,
  Main,
  SyncIndicator,
  Text,
  textStyle,
  TextInput
} from '@aragon/ui'
import styled from 'styled-components'
import {fromDecimals, toDecimals} from './utils'

function App() {
  const { api, appState } = useAragonApi()
  const {
    isSyncing,
    sctBalance,
    sctTokenWrapperBalance,
    stablecoinBalance,
    sctAddress,
    stablecoinAddress,
    earned
  } = appState

  const [stakeAmount, setStakeAmount] = useState(0)
  const [withdrawAmount, setWithdrawAmount] = useState(0)
  const [rewardAmount, setRewardAmount] = useState(0)

  const stake = () => {
    const stakeAmountWithDecimals = toDecimals(stakeAmount, 18)
    api.stake(stakeAmountWithDecimals, {token: { address: sctAddress, value: stakeAmountWithDecimals }, gas: 500000 }).toPromise()
  }

  const createReward = () => {
    const rewardAmountWithDecimals = toDecimals(rewardAmount, 18)
    api.notifyRewardAmount(rewardAmountWithDecimals,  {token: { address: stablecoinAddress, value: rewardAmountWithDecimals }, gas: 500000 }).toPromise()
  }

  return (
    <Main>
      {isSyncing && <SyncIndicator />}
      <Header
        primary="Stablecoin Rewards"
        secondary={
          <Text
            css={`${textStyle('title2')}`}
          />
        }
      />

      <Box
        css={`
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          ${textStyle('title3')};
        `}
      >

        SCT Balance: {fromDecimals(sctBalance ? sctBalance : "", 18)}
        <br/>
        SCT Staked: {fromDecimals(sctTokenWrapperBalance ? sctTokenWrapperBalance : "", 18)}

        <Buttons>
          <div>
            <TextInput
              value={stakeAmount}
              onChange={event => {setStakeAmount(event.target.value)}}
            />

            <Button
              css={`margin-left: 20px`}
              label="Stake"
              onClick={stake}
            />
          </div>

          <div>
            <TextInput
              value={withdrawAmount}
              onChange={event => {setWithdrawAmount(event.target.value)}}
            />

            <Button
              css={`margin-left: 20px`}
              label="Withdraw"
              onClick={() => {api.withdraw(toDecimals(withdrawAmount, 18)).toPromise()}}
            />
          </div>
        </Buttons>

        Stablecoin Balance: {fromDecimals(stablecoinBalance ? stablecoinBalance : "", 18)}
        <br/>
        Stablecoin Claimable: {fromDecimals(earned ? earned : "", 18)}
        <br/>

        <Button
          css={`margin-top: 20px`}
          label="Claim Reward"
          onClick={() => api.getReward().toPromise()}
        />

        <div css={`margin-top: 40px`}>
          <TextInput
            value={rewardAmount}
            onChange={event => {setRewardAmount(event.target.value)}}
          />

          <Button
            css={`margin-left: 20px`}
            label="Distribute Reward"
            onClick={createReward}
          />
        </div>

      </Box>
    </Main>
  )
}

const Buttons = styled.div`
  display: grid;
  grid-auto-flow: row;
  grid-gap: 20px;
  margin-top: 20px;
  margin-bottom: 30px;
`

export default App
